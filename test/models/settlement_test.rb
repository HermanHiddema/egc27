require "test_helper"

# == Schema Information
#
# Table name: settlements
#
#  id                   :bigint           not null, primary key
#  amount_cents         :integer          default(0), not null
#  mollie_created_at    :datetime
#  other_payments       :jsonb            not null
#  payments_complete    :boolean          default(FALSE), not null
#  periods              :jsonb            not null
#  reference            :string
#  settled_at           :datetime
#  status               :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  mollie_balance_id    :string
#  mollie_settlement_id :string           not null
#
# Indexes
#
#  index_settlements_on_mollie_settlement_id  (mollie_settlement_id) UNIQUE
#
class SettlementTest < ActiveSupport::TestCase
  test "requires a unique mollie settlement id" do
    settlement = Settlement.new(mollie_settlement_id: settlements(:paid_out).mollie_settlement_id, status: "paidout")

    assert_not settlement.valid?
    assert settlement.errors.added?(:mollie_settlement_id, :taken, value: settlement.mollie_settlement_id)
  end

  test "requires a known status" do
    settlement = Settlement.new(mollie_settlement_id: "stl_new", status: "bogus")

    assert_not settlement.valid?
    assert settlement.errors.of_kind?(:status, :inclusion)
  end

  test "totals the payments paid out and the deductions by Mollie" do
    settlement = settlements(:paid_out)
    settlement.update!(payments_complete: true)
    payments(:paid_payment).update!(settlement: settlement)

    assert_equal 5_000, settlement.payments_total_cents
    assert_equal 200, settlement.deductions_cents
    assert_equal 200, Settlement.includes(:payments).find(settlement.id).deductions_cents
  end

  test "does not calculate deductions when payments are incomplete" do
    settlement = settlements(:paid_out)
    settlement.update!(payments_complete: false)
    payments(:paid_payment).update!(settlement: settlement)

    assert_nil settlement.deductions_cents
  end

  test "formats amounts in euros" do
    assert_equal "€ 48.00", settlements(:paid_out).amount_formatted
    assert_equal "-€ 1.50", Settlement.format_cents(-150)
  end

  test "labels the paid out status" do
    assert_equal "Paid out", settlements(:paid_out).status_label
    assert_equal "Pending", Settlement.new(status: "pending").status_label
  end

  test "removing a settlement unlinks its payments" do
    settlement = settlements(:paid_out)
    payment = payments(:paid_payment)
    payment.update!(settlement: settlement)

    settlement.destroy!

    assert_nil payment.reload.settlement_id
  end

  test "breaks the payout down per period, oldest first" do
    settlement = settlements(:paid_out)
    settlement.update!(periods: {
      "2026" => {
        "10" => {
          "revenue" => [{ "description" => "iDEAL", "method" => "ideal", "count" => 2,
                           "amount_net" => { "value" => "100.00", "currency" => "EUR" },
                           "amount_gross" => { "value" => "100.00", "currency" => "EUR" } },
                         { "method" => "creditcard", "count" => 1, "amount_gross" => { "value" => "-10.00", "currency" => "EUR" } }],
          "costs" => [{ "description" => "iDEAL", "count" => 2,
                         "amount_net" => { "value" => "0.58", "currency" => "EUR" },
                         "amount_vat" => { "value" => "0.12", "currency" => "EUR" },
                         "amount_gross" => { "value" => "0.70", "currency" => "EUR" } }],
          "invoice_id" => "inv_test1"
        },
        "9" => { "revenue" => [], "costs" => [] }
      }
    })

    september, october = settlement.breakdown_periods

    assert_equal "September 2026", september.label
    assert_equal "October 2026", october.label
    assert_equal "inv_test1", october.invoice_id
    assert_nil september.invoice_id
    assert_equal ["iDEAL", "Creditcard"], october.revenue.map(&:description)
    assert_equal 10_000, october.revenue.first.net_cents
    assert_nil october.revenue.first.vat_cents
    assert_equal 9_000, october.revenue_cents
    assert_equal 70, october.costs_cents
    assert_equal 12, october.costs.first.vat_cents
  end

  test "has no breakdown periods without a breakdown" do
    assert_empty settlements(:paid_out).breakdown_periods
  end

  test "totals the refunds and chargebacks deducted from the payout" do
    settlement = settlements(:paid_out)
    settlement.refunds.create!(mollie_refund_id: "re_1", settlement_amount_cents: -1_000)
    settlement.refunds.create!(mollie_refund_id: "re_2", settlement_amount_cents: -500)
    settlement.chargebacks.create!(mollie_chargeback_id: "chb_1", settlement_amount_cents: -2_500)

    assert_equal(-1_500, settlement.refunds_total_cents)
    assert_equal(-2_500, settlement.chargebacks_total_cents)
    assert_equal(-1_500, Settlement.includes(:refunds).find(settlement.id).refunds_total_cents)
  end

  test "includes payments from another webshop in the totals and deductions" do
    settlement = settlements(:paid_out)
    settlement.update!(payments_complete: true, other_payments: [{ "id" => "tr_other1", "amount_cents" => 1_000 }])
    payments(:paid_payment).update!(settlement: settlement)

    assert_equal 5_000, settlement.payments_total_cents
    assert_equal 1_000, settlement.other_payments_total_cents
    assert_equal 6_000, settlement.all_payments_total_cents
    assert_equal 2, settlement.all_payments_count
    assert_equal 1_200, settlement.deductions_cents
  end

  test "removing a settlement removes its refunds and chargebacks" do
    settlement = settlements(:paid_out)
    settlement.refunds.create!(mollie_refund_id: "re_1")
    settlement.chargebacks.create!(mollie_chargeback_id: "chb_1")

    settlement.destroy!

    assert_not Refund.exists?(mollie_refund_id: "re_1")
    assert_not Chargeback.exists?(mollie_chargeback_id: "chb_1")
  end

  test "converts Mollie amounts to cents" do
    assert_equal 1_234, Settlement.cents_from_amount({ "value" => "12.34", "currency" => "EUR" })
    assert_equal(-50, Settlement.cents_from_amount({ "value" => "-0.50", "currency" => "EUR" }))
    assert_nil Settlement.cents_from_amount(nil)
    assert_nil Settlement.cents_from_amount({ "value" => "bogus" })
  end
end
