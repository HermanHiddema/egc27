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
      { "id" => "stl_new1", "reference" => "1234567.2610.02", "balance_id" => "bal_test123", "status" => "paidout",
        "amount" => { "value" => "185.12", "currency" => "EUR" },
        "settled_at" => "2026-10-05T10:00:00+00:00", "created_at" => "2026-10-04T10:00:00+00:00" }
    ])
    payments = { "stl_new1" => payment_list(%w[tr_paid456 tr_unknown]) }

    result = with_mollie_settlements(remote, payments) do
      MollieSettlementSync.new(token: "access_test").call
    end

    settlement = Settlement.find_by!(mollie_settlement_id: "stl_new1")
    assert_equal "1234567.2610.02", settlement.reference
    assert_equal "bal_test123", settlement.mollie_balance_id
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

    assert_equal %w[access_test access_test access_test access_test], tokens
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

  test "stores the breakdown, refunds and chargebacks of a settlement" do
    periods = {
      "2026" => {
        "10" => {
          "revenue" => [
            { "description" => "iDEAL", "method" => "ideal", "count" => 2,
              "amount_net" => { "value" => "100.00", "currency" => "EUR" }, "amount_vat" => nil,
              "amount_gross" => { "value" => "100.00", "currency" => "EUR" } },
            { "description" => "Refunds iDEAL", "method" => "ideal", "count" => 1,
              "amount_net" => { "value" => "-10.00", "currency" => "EUR" }, "amount_vat" => nil,
              "amount_gross" => { "value" => "-10.00", "currency" => "EUR" } }
          ],
          "costs" => [
            { "description" => "iDEAL", "method" => "ideal", "count" => 2,
              "amount_net" => { "value" => "0.58", "currency" => "EUR" },
              "amount_vat" => { "value" => "0.12", "currency" => "EUR" },
              "amount_gross" => { "value" => "0.70", "currency" => "EUR" } }
          ],
          "invoice_id" => "inv_test1"
        }
      }
    }
    remote = settlement_list([{ "id" => "stl_new1", "status" => "paidout", "amount" => { "value" => "89.30", "currency" => "EUR" },
                                "periods" => periods }])
    refunds = { "stl_new1" => refund_list([{ "id" => "re_test1", "payment_id" => "tr_paid456", "description" => "Cancelled",
                                              "status" => "refunded", "amount" => { "value" => "10.00", "currency" => "EUR" },
                                              "settlement_amount" => { "value" => "-10.00", "currency" => "EUR" },
                                              "created_at" => "2026-10-02T10:00:00+00:00" }]) }
    chargebacks = { "stl_new1" => chargeback_list([{ "id" => "chb_test1", "payment_id" => "tr_unknown",
                                                     "amount" => { "value" => "25.00", "currency" => "EUR" },
                                                     "settlement_amount" => { "value" => "-25.00", "currency" => "EUR" },
                                                     "created_at" => "2026-10-03T10:00:00+00:00" }]) }

    with_mollie_settlements(remote, { "stl_new1" => payment_list([]) }, [], [], refunds, chargebacks) do
      MollieSettlementSync.new(token: "access_test").call
    end

    settlement = Settlement.find_by!(mollie_settlement_id: "stl_new1")
    assert_equal periods, settlement.periods
    refund = settlement.refunds.sole
    assert_equal "re_test1", refund.mollie_refund_id
    assert_equal payments(:paid_payment), refund.payment
    assert_equal "tr_paid456", refund.mollie_payment_id
    assert_equal "Cancelled", refund.description
    assert_equal "refunded", refund.status
    assert_equal 1_000, refund.amount_cents
    assert_equal(-1_000, refund.settlement_amount_cents)
    assert_equal Time.utc(2026, 10, 2, 10), refund.mollie_created_at
    chargeback = settlement.chargebacks.sole
    assert_equal "chb_test1", chargeback.mollie_chargeback_id
    assert_nil chargeback.payment
    assert_equal "tr_unknown", chargeback.mollie_payment_id
    assert_equal 2_500, chargeback.amount_cents
    assert_equal(-2_500, chargeback.settlement_amount_cents)
    assert_not chargeback.reversed?
  end

  test "updates and removes the refunds and chargebacks of a settlement on a resync" do
    settlement = settlements(:paid_out)
    settlement.refunds.create!(mollie_refund_id: "re_gone", settlement_amount_cents: -100)
    Refund.create!(settlement: settlement, mollie_refund_id: "re_kept", settlement_amount_cents: -100)
    settlement.chargebacks.create!(mollie_chargeback_id: "chb_gone")
    remote = settlement_list([{ "id" => settlement.mollie_settlement_id, "status" => "paidout", "amount" => { "value" => "48.00", "currency" => "EUR" } }])
    refunds = { settlement.mollie_settlement_id => refund_list([{ "id" => "re_kept", "payment_id" => "tr_paid456",
                                                                    "settlement_amount" => { "value" => "-2.00", "currency" => "EUR" } }]) }

    with_mollie_settlements(remote, { settlement.mollie_settlement_id => payment_list([]) }, [], [], refunds) do
      MollieSettlementSync.new(token: "access_test").call
    end

    assert_equal %w[re_kept], settlement.refunds.pluck(:mollie_refund_id)
    assert_equal(-200, settlement.refunds.sole.settlement_amount_cents)
    assert_equal payments(:paid_payment), settlement.refunds.sole.payment
    assert_empty settlement.chargebacks.reload
  end

  test "keeps the details of payments from another webshop without importing them" do
    remote = settlement_list([{ "id" => "stl_new1", "status" => "paidout", "amount" => { "value" => "120.00", "currency" => "EUR" } }])
    payments = Mollie::List.new({ "_embedded" => { "payments" => [
      { "id" => "tr_paid456" },
      { "id" => "tr_other1", "description" => "Webshop order 12", "method" => "ideal", "status" => "paid",
        "amount" => { "value" => "75.00", "currency" => "EUR" }, "settlement_amount" => { "value" => "75.00", "currency" => "EUR" },
        "created_at" => "2026-09-20T10:00:00+00:00" }
    ] }, "_links" => {} }, Mollie::Settlement::Payment)

    result = with_mollie_settlements(remote, { "stl_new1" => payments }) do
      MollieSettlementSync.new(token: "access_test").call
    end

    settlement = Settlement.find_by!(mollie_settlement_id: "stl_new1")
    assert_not Payment.exists?(mollie_payment_id: "tr_other1")
    other = settlement.other_payments.sole
    assert_equal "tr_other1", other["id"]
    assert_equal "Webshop order 12", other["description"]
    assert_equal "ideal", other["method"]
    assert_equal 7_500, other["amount_cents"]
    assert_equal 7_500, other["settlement_amount_cents"]
    assert settlement.payments_complete?
    assert_equal 12_500, settlement.all_payments_total_cents
    assert_equal 500, settlement.deductions_cents
    assert_equal 1, result.payments_count
  end

  test "syncs a single settlement" do
    settlement = settlements(:paid_out)
    requested = []
    remote = Mollie::Settlement.new({ "id" => settlement.mollie_settlement_id, "status" => "paidout",
                                      "amount" => { "value" => "48.00", "currency" => "EUR" },
                                      "created_at" => "2026-10-01T10:00:00+00:00", "periods" => { "2026" => { "10" => { "revenue" => [], "costs" => [] } } } })
    original_get = Mollie::Settlement.method(:get)
    Mollie::Settlement.define_singleton_method(:get) do |id, options = {}|
      requested << [id, options[:api_key]]
      remote
    end

    linked = with_mollie_settlements(settlement_list([]), { settlement.mollie_settlement_id => payment_list(%w[tr_paid456]) }) do
      MollieSettlementSync.new(token: "access_test").sync_one(settlement.mollie_settlement_id)
    end

    assert_equal [[settlement.mollie_settlement_id, "access_test"]], requested
    assert_equal 1, linked
    assert_equal settlement, payments(:paid_payment).reload.settlement
    assert_equal({ "2026" => { "10" => { "revenue" => [], "costs" => [] } } }, settlement.reload.periods)
  ensure
    Mollie::Settlement.define_singleton_method(:get, &original_get)
  end

  test "syncing a single settlement requires an organization token" do
    assert_raises(MollieSettlementSync::NotConfigured) do
      MollieSettlementSync.new(token: nil).sync_one("stl_paidout1")
    end
  end

  private

  def refund_list(items)
    Mollie::List.new({ "_embedded" => { "refunds" => items }, "_links" => {} }, Mollie::Settlement::Refund)
  end

  def chargeback_list(items)
    Mollie::List.new({ "_embedded" => { "chargebacks" => items }, "_links" => {} }, Mollie::Settlement::Chargeback)
  end

  def settlement_list(items, links: {})
    items = items.map { |item| { "created_at" => "2026-10-01T10:00:00+00:00" }.merge(item) }
    Mollie::List.new({ "_embedded" => { "settlements" => items }, "_links" => links }, Mollie::Settlement)
  end

  def payment_list(ids)
    Mollie::List.new({ "_embedded" => { "payments" => ids.map { |id| { "id" => id } } }, "_links" => {} }, Mollie::Settlement::Payment)
  end

  def with_mollie_settlements(settlement_list, payment_lists, tokens = [], settlement_options = [], refund_lists = {}, chargeback_lists = {})
    original_all = Mollie::Settlement.method(:all)
    original_payments_all = Mollie::Settlement::Payment.method(:all)
    original_refunds_all = Mollie::Settlement::Refund.method(:all)
    original_chargebacks_all = Mollie::Settlement::Chargeback.method(:all)
    no_refunds = refund_list([])
    no_chargebacks = chargeback_list([])
    Mollie::Settlement.define_singleton_method(:all) do |options = {}|
      settlement_options << options.except(:api_key)
      tokens << options[:api_key]
      settlement_list
    end
    Mollie::Settlement::Payment.define_singleton_method(:all) do |options = {}|
      tokens << options[:api_key]
      payment_lists.fetch(options[:settlement_id])
    end
    Mollie::Settlement::Refund.define_singleton_method(:all) do |options = {}|
      tokens << options[:api_key]
      refund_lists.fetch(options[:settlement_id]) { no_refunds }
    end
    Mollie::Settlement::Chargeback.define_singleton_method(:all) do |options = {}|
      tokens << options[:api_key]
      chargeback_lists.fetch(options[:settlement_id]) { no_chargebacks }
    end
    yield
  ensure
    Mollie::Settlement.define_singleton_method(:all, &original_all)
    Mollie::Settlement::Payment.define_singleton_method(:all, &original_payments_all)
    Mollie::Settlement::Refund.define_singleton_method(:all, &original_refunds_all)
    Mollie::Settlement::Chargeback.define_singleton_method(:all, &original_chargebacks_all)
  end
end
