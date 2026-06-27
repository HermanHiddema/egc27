require "test_helper"
require "ostruct"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  # new
  test "new redirects visitors to participant page" do
    participant = participants(:one)
    participant.update!(participant_type: "visitor")

    get new_participant_payment_path(participant)

    assert_redirected_to participant_path(participant)
  end

  test "new shows unconfirmed notice for unconfirmed player" do
    participant = participants(:unconfirmed)

    get new_participant_payment_path(participant)

    assert_response :success
    assert_match "confirm", response.body
    assert_no_match participant.email, response.body
  end

  test "new builds a fresh payment for confirmed player" do
    participant = participants(:one)

    get new_participant_payment_path(participant)

    assert_response :success
  end

  test "new shows paid state for participant with completed payment" do
    participant = participants(:two)

    get new_participant_payment_path(participant)

    assert_response :success
    assert_match "already been paid", response.body
  end

  # create
  test "create redirects unconfirmed participant back to new" do
    participant = participants(:unconfirmed)

    post participant_payment_path(participant)

    assert_redirected_to new_participant_payment_path(participant)
  end

  test "create redirects visitor to participant page" do
    participant = participants(:one)
    participant.update!(participant_type: "visitor")

    post participant_payment_path(participant)

    assert_redirected_to participant_path(participant)
  end

  test "create redirects to success page when payment already completed" do
    participant = participants(:two)

    post participant_payment_path(participant)

    assert_redirected_to success_payments_path
  end

  test "create keeps confirmed payment view state when mollie creation fails" do
    participant = participants(:three)

    original = Mollie::Payment.method(:create)
    Mollie::Payment.define_singleton_method(:create) { |_params| raise Mollie::Exception, "boom" }

    post participant_payment_path(participant)

    assert_response :unprocessable_entity
    assert_match "Payment could not be started: boom", response.body
    assert_no_match "Please confirm your email address", response.body
  ensure
    Mollie::Payment.define_singleton_method(:create, original)
  end

  test "create reuses the latest in-progress payment" do
    payment = payments(:open_payment)
    mollie_stub = OpenStruct.new(id: payment.mollie_payment_id, checkout_url: "https://example.test/mollie-checkout")

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    assert_no_difference("Payment.count") do
      post participant_payment_path(payment.participant)
    end

    assert_redirected_to "https://example.test/mollie-checkout"
  ensure
    Mollie::Payment.define_singleton_method(:get, original)
  end

  # success
  test "success renders page without payment_id" do
    get success_payments_path

    assert_response :success
  end

  test "success renders page with unknown payment_id" do
    get success_payments_path(payment_id: 0)

    assert_response :success
  end

  test "success treats authorized payments as pending" do
    payment = payments(:open_payment)
    payment.update!(status: "authorized")
    mollie_stub = OpenStruct.new(id: payment.mollie_payment_id, status: "authorized")

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    get success_payments_path(payment_id: payment.id)

    assert_response :success
    assert_match "Payment Pending", response.body
  ensure
    Mollie::Payment.define_singleton_method(:get, original)
  end

  # webhook
  test "webhook returns ok on unknown mollie id" do
    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| raise Mollie::Exception, "not found" }

    post webhook_payments_path, params: { id: "tr_unknown" }

    assert_response :ok
  ensure
    Mollie::Payment.define_singleton_method(:get, original)
  end

  test "webhook updates payment status" do
    payment = payments(:open_payment)
    mollie_stub = OpenStruct.new(id: payment.mollie_payment_id, status: "paid")

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    post webhook_payments_path, params: { id: payment.mollie_payment_id }

    assert_response :ok
    assert_equal "paid", payment.reload.status
  ensure
    Mollie::Payment.define_singleton_method(:get, original)
  end

  test "webhook is not blocked by the modern browser guard" do
    payment = payments(:open_payment)
    mollie_stub = OpenStruct.new(id: payment.mollie_payment_id, status: "paid")

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    outdated_browser_user_agent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " \
      "(KHTML, like Gecko) Chrome/90.0.4430.93 Safari/537.36"

    assert_enqueued_emails 1 do
      post webhook_payments_path,
        params: { id: payment.mollie_payment_id },
        headers: { "HTTP_USER_AGENT" => outdated_browser_user_agent }
    end

    assert_response :ok
    assert_equal "paid", payment.reload.status
  ensure
    Mollie::Payment.define_singleton_method(:get, original)
  end
end
