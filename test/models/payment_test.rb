require "test_helper"

# == Schema Information
#
# Table name: payments
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer          not null
#  confirmation_sent :boolean          default(FALSE), not null
#  description       :string           not null
#  payment_method    :string
#  provider          :string           default("mollie"), not null
#  reference         :string
#  status            :string           default("open"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  mollie_payment_id :string
#  participant_id    :bigint           not null
#
# Indexes
#
#  index_payments_on_mollie_payment_id  (mollie_payment_id) UNIQUE
#  index_payments_on_participant_id     (participant_id)
#  index_payments_on_provider           (provider)
#  index_payments_on_status             (status)
#
# Foreign Keys
#
#  fk_rails_...  (participant_id => participants.id)
#
class PaymentTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

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

  test "sends payment confirmation email when status changes to paid" do
    payment = payments(:open_payment)
    assert_emails 1 do
      payment.update!(status: "paid")
    end
  end

  test "does not send payment confirmation email when status changes to a non-paid status" do
    payment = payments(:open_payment)
    assert_no_emails do
      payment.update!(status: "failed")
    end
  end

  test "does not send payment confirmation email when confirmation_sent is already true" do
    payment = payments(:open_payment)
    payment.update_columns(confirmation_sent: true)
    assert_no_emails do
      payment.update!(status: "paid")
    end
  end

  test "does not resend payment confirmation email when an already paid payment is saved" do
    payment = payments(:paid_payment)
    assert_no_emails do
      payment.update!(status: "paid")
    end
  end

  test "defaults to the mollie provider" do
    payment = Payment.new(participant: participants(:one))
    assert_equal "mollie", payment.provider
    assert_not payment.manual?
  end

  test "validates provider inclusion" do
    payment = Payment.new(
      participant: participants(:one),
      status: "paid",
      amount_cents: 19_000,
      description: "Test",
      provider: "paypal"
    )
    assert_not payment.valid?
    assert payment.errors[:provider].any?
  end

  test "validates payment_method inclusion for manual payments" do
    payment = Payment.new(
      participant: participants(:one),
      status: "paid",
      amount_cents: 19_000,
      description: "Test",
      provider: "manual",
      payment_method: "bitcoin"
    )
    assert_not payment.valid?
    assert payment.errors[:payment_method].any?
  end

  test "allows any payment method reported by mollie" do
    payment = Payment.new(
      participant: participants(:one),
      status: "paid",
      amount_cents: 19_000,
      description: "Test",
      provider: "mollie",
      payment_method: "ideal"
    )
    assert payment.valid?
  end

  test "allows a blank payment method for mollie payments" do
    assert payments(:open_payment).valid?
    assert_nil payments(:open_payment).payment_method
  end

  test "manual? is true for payments received outside mollie" do
    assert payments(:manual_payment).manual?
    assert_not payments(:paid_payment).manual?
  end

  test "manual scope returns manually recorded payments" do
    assert_includes Payment.manual, payments(:manual_payment)
    assert_not_includes Payment.manual, payments(:paid_payment)
  end

  test "labels humanize the provider and payment method" do
    assert_equal "Manual", payments(:manual_payment).provider_label
    assert_equal "Bank transfer", payments(:manual_payment).payment_method_label
    assert_nil payments(:open_payment).payment_method_label
  end

  test "sends payment confirmation email when created as paid" do
    assert_emails 1 do
      Payment.create!(
        participant: participants(:one),
        status: "paid",
        amount_cents: 19_000,
        description: "Cash at the venue",
        provider: "manual",
        payment_method: "cash"
      )
    end
  end

  test "does not send payment confirmation email when created as open" do
    assert_no_emails do
      Payment.create!(
        participant: participants(:one),
        status: "open",
        amount_cents: 19_000,
        description: "Bank transfer pending",
        provider: "manual",
        payment_method: "bank_transfer"
      )
    end
  end
end
