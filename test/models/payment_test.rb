require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  test "valid payment with required attributes" do
    payment = Payment.new(
      participant: participants(:one),
      status: "open",
      amount_cents: 19_000,
      description: "EGC 2027 Congress Pass – Full (Week 1 + Weekend + Week 2)"
    )
    assert payment.valid?
  end

  test "requires participant" do
    payment = Payment.new(status: "open", amount_cents: 19_000, description: "Test")
    assert_not payment.valid?
    assert_includes payment.errors[:participant], "must exist"
  end

  test "requires description" do
    payment = Payment.new(participant: participants(:one), status: "open", amount_cents: 19_000)
    assert_not payment.valid?
    assert_includes payment.errors[:description], "can't be blank"
  end

  test "requires positive amount_cents" do
    payment = Payment.new(participant: participants(:one), status: "open", amount_cents: 0, description: "Test")
    assert_not payment.valid?
    assert payment.errors[:amount_cents].any?
  end

  test "validates status inclusion" do
    payment = Payment.new(
      participant: participants(:one),
      status: "invalid",
      amount_cents: 19_000,
      description: "Test"
    )
    assert_not payment.valid?
    assert payment.errors[:status].any?
  end

  test "paid? returns true for paid status" do
    assert payments(:paid_payment).paid?
  end

  test "paid? returns false for open status" do
    assert_not payments(:open_payment).paid?
  end

  test "amount_eur divides cents by 100" do
    payment = payments(:open_payment)
    assert_equal 190.0, payment.amount_eur
  end

  test "amount_formatted returns euro formatted string" do
    payment = payments(:open_payment)
    assert_equal "€ 190.00", payment.amount_formatted
  end

  test "completed scope returns paid payments" do
    assert_includes Payment.completed, payments(:paid_payment)
    assert_not_includes Payment.completed, payments(:open_payment)
  end

  test "pending_or_open scope returns open payments" do
    assert_includes Payment.pending_or_open, payments(:open_payment)
    assert_not_includes Payment.pending_or_open, payments(:paid_payment)
  end
end
