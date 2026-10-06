require "test_helper"

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
    payments(:paid_payment).update!(settlement: settlement)

    assert_equal 5_000, settlement.payments_total_cents
    assert_equal 200, settlement.deductions_cents
    assert_equal 200, Settlement.includes(:payments).find(settlement.id).deductions_cents
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
end
