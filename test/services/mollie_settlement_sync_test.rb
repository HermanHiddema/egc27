require "test_helper"

class MollieSettlementSyncTest < ActiveSupport::TestCase
  test "is not configured without an organization token" do
    assert_raises(MollieSettlementSync::NotConfigured) do
      MollieSettlementSync.new(token: nil).call
    end
  end

  test "records settlements and links the payments paid out in them" do
    remote = settlement_list([
      { "id" => "stl_new1", "reference" => "1234567.2610.02", "status" => "paidout",
        "amount" => { "value" => "185.12", "currency" => "EUR" },
        "settled_at" => "2026-10-05T10:00:00+00:00", "created_at" => "2026-10-04T10:00:00+00:00" }
    ])
    payments = { "stl_new1" => payment_list(%w[tr_paid456 tr_unknown]) }

    result = with_mollie_settlements(remote, payments) do
      MollieSettlementSync.new(token: "access_test").call
    end

    settlement = Settlement.find_by!(mollie_settlement_id: "stl_new1")
    assert_equal "1234567.2610.02", settlement.reference
    assert_equal "paidout", settlement.status
    assert_equal 18_512, settlement.amount_cents
    assert_equal Time.utc(2026, 10, 5, 10), settlement.settled_at
    assert_equal settlement, payments(:paid_payment).reload.settlement
    assert_nil payments(:open_payment).reload.settlement
    assert_equal 1, result.settlements_count
    assert_equal 1, result.payments_count
  end

  test "passes the organization token to Mollie" do
    tokens = []
    remote = settlement_list([{ "id" => "stl_new1", "status" => "pending", "amount" => { "value" => "1.00", "currency" => "EUR" } }])

    with_mollie_settlements(remote, { "stl_new1" => payment_list([]) }, tokens) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_equal %w[access_test access_test], tokens
  end

  test "follows the pagination of Mollie lists" do
    first_page = settlement_list(
      [{ "id" => "stl_new1", "status" => "pending", "amount" => { "value" => "1.00", "currency" => "EUR" } }],
      links: { "next" => { "href" => "https://api.mollie.com/v2/settlements?from=stl_new2" } }
    )
    second_page = settlement_list([{ "id" => "stl_new2", "status" => "pending", "amount" => { "value" => "2.00", "currency" => "EUR" } }])
    first_page.define_singleton_method(:next) { |_options = {}| second_page }

    with_mollie_settlements(first_page, { "stl_new1" => payment_list([]), "stl_new2" => payment_list(%w[tr_paid456]) }) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_equal %w[stl_new1 stl_new2], Settlement.where(mollie_settlement_id: %w[stl_new1 stl_new2]).order(:mollie_settlement_id).pluck(:mollie_settlement_id)
    assert_equal "stl_new2", payments(:paid_payment).reload.settlement.mollie_settlement_id
  end

  test "updates an existing settlement that was not paid out yet" do
    settlement = settlements(:paid_out)
    settlement.update!(status: "pending")
    remote = settlement_list([{ "id" => settlement.mollie_settlement_id, "reference" => settlement.reference, "status" => "paidout",
                                 "amount" => { "value" => "48.00", "currency" => "EUR" } }])

    with_mollie_settlements(remote, { settlement.mollie_settlement_id => payment_list(%w[tr_paid456]) }) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_equal "paidout", settlement.reload.status
    assert_equal settlement, payments(:paid_payment).reload.settlement
  end

  test "does not fetch the payments of a settlement that was already paid out again" do
    settlement = settlements(:paid_out)
    remote = settlement_list([{ "id" => settlement.mollie_settlement_id, "status" => "paidout", "amount" => { "value" => "48.00", "currency" => "EUR" } }])

    with_mollie_settlements(remote, {}) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_equal "paidout", settlement.reload.status
  end

  test "skips settlements with an unknown status" do
    remote = settlement_list([{ "id" => "stl_weird", "status" => "bogus", "amount" => { "value" => "1.00", "currency" => "EUR" } }])

    result = with_mollie_settlements(remote, {}) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_not Settlement.exists?(mollie_settlement_id: "stl_weird")
    assert_equal 0, result.settlements_count
  end

  private

  def settlement_list(items, links: {})
    Mollie::List.new({ "_embedded" => { "settlements" => items }, "_links" => links }, Mollie::Settlement)
  end

  def payment_list(ids)
    Mollie::List.new({ "_embedded" => { "payments" => ids.map { |id| { "id" => id } } }, "_links" => {} }, Mollie::Settlement::Payment)
  end

  def with_mollie_settlements(settlement_list, payment_lists, tokens = [])
    original_all = Mollie::Settlement.method(:all)
    original_payments_all = Mollie::Settlement::Payment.method(:all)
    Mollie::Settlement.define_singleton_method(:all) do |options = {}|
      tokens << options[:api_key]
      settlement_list
    end
    Mollie::Settlement::Payment.define_singleton_method(:all) do |options = {}|
      tokens << options[:api_key]
      payment_lists.fetch(options[:settlement_id])
    end
    yield
  ensure
    Mollie::Settlement.define_singleton_method(:all, &original_all)
    Mollie::Settlement::Payment.define_singleton_method(:all, &original_payments_all)
  end
end
