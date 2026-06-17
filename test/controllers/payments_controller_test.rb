require "test_helper"
require "ostruct"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
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
  end

  test "new builds a fresh payment for confirmed player" do
    participant = participants(:one)

    get new_participant_payment_path(participant)

    assert_response :success
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

  # success
  test "success renders page without payment_id" do
    get success_payments_path

    assert_response :success
  end

  test "success renders page with unknown payment_id" do
    get success_payments_path(payment_id: 0)

    assert_response :success
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
end
