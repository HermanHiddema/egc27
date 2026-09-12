require "test_helper"
require "ostruct"

# == Schema Information
#
# Table name: payments
#
#  id                       :bigint           not null, primary key
#  amount_cents             :integer          not null
#  confirmation_sent        :boolean          default(FALSE), not null
#  description              :string           not null
#  payment_method           :string
#  processed_in_bookkeeping :boolean          default(FALSE), not null
#  provider                 :string           default("mollie"), not null
#  reference                :string
#  status                   :string           default("open"), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  mollie_payment_id        :string
#  participant_id           :bigint           not null
#
# Indexes
#
#  index_payments_on_mollie_payment_id         (mollie_payment_id) UNIQUE
#  index_payments_on_participant_id            (participant_id)
#  index_payments_on_processed_in_bookkeeping  (processed_in_bookkeeping)
#  index_payments_on_provider                  (provider)
#  index_payments_on_status                    (status)
#
# Foreign Keys
#
#  fk_rails_...  (participant_id => participants.id)
#
class PaymentTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  test "valid payment with required attributes" do
    payment = Payment.new(
      participant: participants(:one),
      status: "open",
      amount_cents: 19_000,
      description: "EGC 2027 All events"
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

  test "unsuccessful? is true for payments that can never succeed anymore" do
    payment = payments(:open_payment)

    Payment::UNSUCCESSFUL_STATUSES.each do |status|
      payment.update!(status: status)
      assert payment.unsuccessful?, "expected #{status} to be unsuccessful"
    end

    %w[open pending authorized paid].each do |status|
      payment.update!(status: status)
      assert_not payment.unsuccessful?, "expected #{status} not to be unsuccessful"
    end
  end

  test "refunded payment is no longer paid and does not block a new payment" do
    payment = payments(:paid_payment)
    payment.update!(status: "refunded")

    assert payment.refunded?
    assert_not payment.paid?
    assert payment.unsuccessful?
    assert_includes Payment.refunded, payment
    assert_not_includes Payment.completed, payment
    assert_not_includes Payment.blocking, payment
  end

  test "unsuccessful and blocking scopes filter on the status" do
    expired = payments(:open_payment)
    expired.update!(status: "expired")

    assert_includes Payment.unsuccessful, expired
    assert_not_includes Payment.unsuccessful, payments(:paid_payment)
    assert_includes Payment.blocking, payments(:paid_payment)
    assert_not_includes Payment.blocking, expired
  end

  test "processed and unprocessed scopes filter on the bookkeeping flag" do
    processed = payments(:manual_payment)
    processed.update!(processed_in_bookkeeping: true)

    assert_includes Payment.processed, processed
    assert_not_includes Payment.processed, payments(:paid_payment)
    assert_includes Payment.unprocessed, payments(:paid_payment)
    assert_not_includes Payment.unprocessed, processed
  end

  test "payments are not processed in bookkeeping by default" do
    payment = Payment.create!(
      participant: participants(:one),
      status: "open",
      amount_cents: 19_000,
      description: "Bank transfer pending",
      provider: "manual",
      payment_method: "bank_transfer"
    )

    assert_not payment.processed_in_bookkeeping?
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

  test "disallows mollie payment id on manual payments" do
    payment = Payment.new(
      participant: participants(:one),
      status: "paid",
      amount_cents: 19_000,
      description: "Test",
      provider: "manual",
      payment_method: "cash",
      mollie_payment_id: "tr_manual"
    )

    assert_not payment.valid?
    assert payment.errors[:mollie_payment_id].any?
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
    assert_equal "Point of sale", Payment.payment_method_label("pointofsale")
    assert_equal "PayPal", Payment.payment_method_label("paypal")
  end

  test "accepts pointofsale and paypal as manual payment methods" do
    payment = payments(:manual_payment)

    payment.payment_method = "pointofsale"
    assert payment.valid?

    payment.payment_method = "paypal"
    assert payment.valid?
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
  # Mollie integration
  test "build_for builds an unsaved open payment for the current price" do
    participant = participants(:three)

    payment = nil
    travel_to(Time.zone.local(2026, 8, 1)) { payment = Payment.build_for(participant) }

    assert_not payment.persisted?
    assert_equal "open", payment.status
    assert_equal participant, payment.participant
    assert_equal 19_000, payment.amount_cents
    assert_equal "EGC 2027 All events - #{participant.participant_number}", payment.description
  end

  test "price_valid_until uses the date the payment was created" do
    payment = payments(:open_payment)
    payment.update!(created_at: Time.zone.local(2026, 8, 15))

    travel_to Time.zone.local(2026, 9, 10) do
      assert_equal Date.new(2026, 8, 31), payment.price_valid_until
    end
  end

  test "sync_from_mollie! records the status and reported payment method" do
    payment = payments(:open_payment)

    payment.sync_from_mollie!(OpenStruct.new(status: "paid", attributes: { "method" => "ideal" }))

    payment.reload
    assert_equal "paid", payment.status
    assert_equal "ideal", payment.payment_method
  end

  test "sync_from_mollie! keeps the existing payment method when Mollie reports none" do
    payment = payments(:paid_payment)

    payment.sync_from_mollie!(OpenStruct.new(status: "paid"))

    assert_equal "ideal", payment.reload.payment_method
  end

  test "sync_from_mollie! records a refunded Mollie payment as refunded" do
    payment = payments(:paid_payment)

    payment.sync_from_mollie!(
      OpenStruct.new(status: "paid", amount_refunded: OpenStruct.new(value: BigDecimal("10.00"), currency: "EUR"))
    )

    assert_equal "refunded", payment.reload.status
  end

  test "refresh_from_mollie! does nothing without a Mollie payment id" do
    payment = payments(:manual_payment)

    assert_nil payment.refresh_from_mollie!
    assert_equal "paid", payment.reload.status
  end

  test "refresh_from_mollie swallows Mollie errors" do
    payment = payments(:open_payment)

    with_mollie_get(->(_id) { raise Mollie::Exception, "boom" }) do
      assert_nil payment.refresh_from_mollie
    end

    assert_equal "open", payment.reload.status
  end

  test "resume_mollie_checkout! returns the checkout url of a retryable payment" do
    payment = payments(:open_payment)
    remote = OpenStruct.new(id: payment.mollie_payment_id, status: "pending", checkout_url: "https://example.test/checkout")

    with_mollie_get(->(_id) { remote }) do
      assert_equal "https://example.test/checkout", payment.resume_mollie_checkout!
    end

    assert_equal "pending", payment.reload.status
  end

  test "resume_mollie_checkout! returns nil when the checkout can no longer be completed" do
    payment = payments(:open_payment)
    remote = OpenStruct.new(id: payment.mollie_payment_id, status: "failed", checkout_url: "https://example.test/checkout")

    with_mollie_get(->(_id) { remote }) do
      assert_nil payment.resume_mollie_checkout!
    end

    assert_equal "failed", payment.reload.status
  end

  test "start_mollie_checkout! stores the Mollie id and returns the checkout url" do
    payment = payments(:open_payment)
    payment.update!(mollie_payment_id: nil)
    created_params = nil
    remote = OpenStruct.new(id: "tr_started_123", checkout_url: "https://example.test/new-checkout")

    with_mollie_create(->(params) { created_params = params; remote }) do
      assert_equal "https://example.test/new-checkout",
        payment.start_mollie_checkout!(redirect_url: "https://egc2027.test/return", webhook_url: "https://egc2027.test/hook")
    end

    assert_equal "tr_started_123", payment.reload.mollie_payment_id
    assert_equal payment.description, created_params[:description]
    assert_equal "190.00", created_params[:amount][:value]
    assert_equal "https://egc2027.test/hook", created_params[:webhook_url]
  end

  test "start_mollie_checkout! raises when Mollie returns no checkout url" do
    payment = payments(:open_payment)

    with_mollie_create(->(_params) { OpenStruct.new(id: "tr_no_url", checkout_url: nil) }) do
      assert_raises(Mollie::Exception) do
        payment.start_mollie_checkout!(redirect_url: "https://egc2027.test/return", webhook_url: "https://egc2027.test/hook")
      end
    end
  end

  test "sync_from_mollie_webhook updates the matching payment" do
    payment = payments(:open_payment)
    remote = OpenStruct.new(id: payment.mollie_payment_id, status: "paid")

    with_mollie_get(->(_id) { remote }) do
      assert_equal payment, Payment.sync_from_mollie_webhook(payment.mollie_payment_id)
    end

    assert_equal "paid", payment.reload.status
  end

  test "sync_from_mollie_webhook ignores unknown payments" do
    with_mollie_get(->(id) { OpenStruct.new(id: id, status: "paid") }) do
      assert_nil Payment.sync_from_mollie_webhook("tr_unknown")
    end
  end

  test "simulate_mollie_status! records the simulated status without a Mollie id" do
    payment = payments(:open_payment)

    payment.simulate_mollie_status!("failed")

    payment.reload
    assert_equal "failed", payment.status
    assert_nil payment.mollie_payment_id
  end

  private

  def with_mollie_get(stub)
    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |id| stub.call(id) }
    yield
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  def with_mollie_create(stub)
    original = Mollie::Payment.method(:create)
    Mollie::Payment.define_singleton_method(:create) { |**params| stub.call(params) }
    yield
  ensure
    Mollie::Payment.define_singleton_method(:create, &original)
  end
end
