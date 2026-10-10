require "test_helper"

class MollieSettlementSyncTest < ActiveSupport::TestCase
  setup do
    Payment.update_all(created_at: Time.utc(2026, 9, 1, 12))
  end

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
    assert_not settlement.payments_complete?
    assert_nil settlement.deductions_cents
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
    assert settlement.payments_complete?
    assert_equal settlement, payments(:paid_payment).reload.settlement
  end

  test "unlinks payments removed from a non-final settlement" do
    settlement = settlements(:paid_out)
    settlement.update!(status: "pending")
    payments(:paid_payment).update!(settlement: settlement)
    remote = settlement_list([{ "id" => settlement.mollie_settlement_id, "status" => "pending",
                                "amount" => { "value" => "48.00", "currency" => "EUR" } }])

    with_mollie_settlements(remote, { settlement.mollie_settlement_id => payment_list([]) }) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_nil payments(:paid_payment).reload.settlement_id
  end

  test "fetches the payments of a known paid out settlement again" do
    settlement = settlements(:paid_out)
    settlement.update!(payments_complete: true)
    remote = settlement_list([{ "id" => settlement.mollie_settlement_id, "status" => "paidout", "amount" => { "value" => "48.00", "currency" => "EUR" } }])

    with_mollie_settlements(remote, { settlement.mollie_settlement_id => payment_list(%w[tr_paid456 tr_unknown]) }) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_not settlement.reload.payments_complete?
    assert_equal settlement, payments(:paid_payment).reload.settlement
  end

  test "skips settlements with an unknown status" do
    remote = settlement_list([{ "id" => "stl_weird", "status" => "bogus", "amount" => { "value" => "1.00", "currency" => "EUR" } }])

    result = with_mollie_settlements(remote, {}) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_not Settlement.exists?(mollie_settlement_id: "stl_weird")
    assert_equal 0, result.settlements_count
  end

  test "rejects a paid out settlement with a missing amount instead of storing zero" do
    remote = settlement_list([{ "id" => "stl_missing_amount", "status" => "paidout" }])

    error = assert_raises(Mollie::Exception) do
      with_mollie_settlements(remote, { "stl_missing_amount" => payment_list(%w[tr_paid456]) }) do
        MollieSettlementSync.new(token: "access_test").call
      end
    end

    assert_equal "Settlement stl_missing_amount is missing its payout amount.", error.message
    assert_not Settlement.exists?(mollie_settlement_id: "stl_missing_amount")
  end

  test "rejects a missing amount even when the paid out settlement is already complete" do
    settlement = settlements(:paid_out)
    settlement.update!(payments_complete: true)
    remote = settlement_list([{ "id" => settlement.mollie_settlement_id, "status" => "paidout" }])

    assert_raises(Mollie::Exception) do
      with_mollie_settlements(remote, {}) do
        MollieSettlementSync.new(token: "access_test").call
      end
    end

    assert_equal 4800, settlement.reload.amount_cents
  end

  test "skips settlements created before the date of the first Mollie payment" do
    remote = settlement_list([
      { "id" => "stl_same_day", "status" => "pending", "amount" => { "value" => "2.00", "currency" => "EUR" },
        "created_at" => "2026-09-01T08:00:00+00:00" },
      { "id" => "stl_before", "status" => "paidout", "amount" => { "value" => "1.00", "currency" => "EUR" },
        "created_at" => "2026-08-31T23:00:00+00:00" }
    ])

    result = with_mollie_settlements(remote, { "stl_same_day" => payment_list([]) }) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_not Settlement.exists?(mollie_settlement_id: "stl_before")
    assert Settlement.exists?(mollie_settlement_id: "stl_same_day")
    assert_equal 1, result.settlements_count
  end

  test "ignores the date of the first manual payment" do
    payments(:manual_payment).update_columns(created_at: Time.utc(2026, 1, 1, 12))
    remote = settlement_list([{ "id" => "stl_before", "status" => "pending", "amount" => { "value" => "1.00", "currency" => "EUR" },
                                "created_at" => "2026-06-01T10:00:00+00:00" }])

    with_mollie_settlements(remote, {}) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_not Settlement.exists?(mollie_settlement_id: "stl_before")
  end

  test "does not fetch settlements without any Mollie payments" do
    Payment.where(provider: "mollie").delete_all
    requested = false
    original_all = Mollie::Settlement.method(:all)
    Mollie::Settlement.define_singleton_method(:all) { |_options = {}| requested = true }

    result = MollieSettlementSync.new(token: "access_test").call

    assert_not requested
    assert_equal 0, result.settlements_count
  ensure
    Mollie::Settlement.define_singleton_method(:all, &original_all)
  end

  test "limits settlements to the configured balance" do
    options = []
    remote = settlement_list([])

    with_mollie_settlements(remote, {}, [], options) do
      MollieSettlementSync.new(token: "access_test", balance_id: "bal_test123").call
    end

    assert_equal "bal_test123", options.first[:balance_id]
  end

  test "does not limit settlements to a balance by default" do
    options = []

    with_mollie_settlements(settlement_list([]), {}, [], options) do
      MollieSettlementSync.new(token: "access_test", balance_id: nil).call
    end

    assert_not options.first.key?(:balance_id)
  end

  test "reads the balance from the environment" do
    original = ENV["MOLLIE_SETTLEMENT_BALANCE_ID"]
    ENV["MOLLIE_SETTLEMENT_BALANCE_ID"] = "bal_env456"
    assert_equal "bal_env456", MollieSettlementSync.balance_id
    ENV["MOLLIE_SETTLEMENT_BALANCE_ID"] = ""
    assert_nil MollieSettlementSync.balance_id
  ensure
    ENV["MOLLIE_SETTLEMENT_BALANCE_ID"] = original
  end

  test "stops at the first settlement created before the first Mollie payment" do
    remote = settlement_list([
      { "id" => "stl_same_day", "status" => "pending", "amount" => { "value" => "2.00", "currency" => "EUR" },
        "created_at" => "2026-09-01T08:00:00+00:00" },
      { "id" => "stl_before", "status" => "paidout", "amount" => { "value" => "1.00", "currency" => "EUR" },
        "created_at" => "2026-08-31T23:00:00+00:00" }
    ], links: { "next" => { "href" => "https://api.mollie.com/v2/settlements?from=stl_older" } })
    remote.define_singleton_method(:next) { |_options = {}| raise "should not fetch the next page" }

    result = with_mollie_settlements(remote, { "stl_same_day" => payment_list([]) }) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_equal 1, result.settlements_count
  end

  test "continues past settlements that were already synced and are final" do
    settlements(:paid_out).update!(mollie_created_at: Time.utc(2026, 10, 1, 10))
    remote = settlement_list([
      { "id" => "stl_new1", "status" => "open", "amount" => { "value" => "2.00", "currency" => "EUR" },
        "created_at" => "2026-10-02T10:00:00+00:00" },
      { "id" => "stl_paidout1", "status" => "paidout", "amount" => { "value" => "48.00", "currency" => "EUR" },
        "created_at" => "2026-10-01T10:00:00+00:00" },
      { "id" => "stl_old", "status" => "paidout", "amount" => { "value" => "1.00", "currency" => "EUR" },
        "created_at" => "2026-09-15T10:00:00+00:00" }
    ])

    with_mollie_settlements(remote, { "stl_new1" => payment_list([]), "stl_paidout1" => payment_list([]),
                                     "stl_old" => payment_list([]) }) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert Settlement.exists?(mollie_settlement_id: "stl_new1")
    assert Settlement.exists?(mollie_settlement_id: "stl_old")
  end

  test "keeps fetching past final settlements until older open settlements are reached" do
    settlements(:paid_out).update!(mollie_created_at: Time.utc(2026, 10, 1, 10))
    pending = Settlement.create!(mollie_settlement_id: "stl_pending", status: "pending", mollie_created_at: Time.utc(2026, 9, 15, 10))
    remote = settlement_list([
      { "id" => "stl_paidout1", "status" => "paidout", "amount" => { "value" => "48.00", "currency" => "EUR" },
        "created_at" => "2026-10-01T10:00:00+00:00" },
      { "id" => "stl_pending", "status" => "paidout", "amount" => { "value" => "5.00", "currency" => "EUR" },
        "created_at" => "2026-09-15T10:00:00+00:00" }
    ])

    with_mollie_settlements(remote, { "stl_paidout1" => payment_list([]), "stl_pending" => payment_list(%w[tr_paid456]) }) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_equal "paidout", pending.reload.status
    assert_equal pending, payments(:paid_payment).reload.settlement
  end

  private

  def settlement_list(items, links: {})
    items = items.map { |item| { "created_at" => "2026-10-01T10:00:00+00:00" }.merge(item) }
    Mollie::List.new({ "_embedded" => { "settlements" => items }, "_links" => links }, Mollie::Settlement)
  end

  def payment_list(ids)
    Mollie::List.new({ "_embedded" => { "payments" => ids.map { |id| { "id" => id } } }, "_links" => {} }, Mollie::Settlement::Payment)
  end

  def with_mollie_settlements(settlement_list, payment_lists, tokens = [], settlement_options = [])
    original_all = Mollie::Settlement.method(:all)
    original_payments_all = Mollie::Settlement::Payment.method(:all)
    Mollie::Settlement.define_singleton_method(:all) do |options = {}|
      settlement_options << options.except(:api_key)
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
