require "test_helper"
require "ostruct"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  def post_payment(participant, **options)
    sign_in participant.user
    post participant_payment_path(participant), **options
  end

  # The Participant payment routes remain as compatibility redirects. All
  # checkout and retry actions now happen from the basket or a submitted Order.
  test "new redirects a participant with a draft Order to the shopping basket" do
    participant = participants(:three)
    participant.add_ticket_to_draft_order!
    sign_in participant.user

    get new_participant_payment_path(participant)

    assert_redirected_to order_path
  end

  test "new redirects a participant with a submitted Order to that Order" do
    participant = participants(:one)
    sign_in participant.user

    get new_participant_payment_path(participant)

    assert_redirected_to submitted_order_path(participant.order)
  end

  test "new redirects visitors to participant page" do
    participant = participants(:one)
    participant.update!(participant_type: "visitor")

    get new_participant_payment_path(participant)

    assert_redirected_to participant_path(participant)
  end

  test "new requires a signed-in owner" do
    get new_participant_payment_path(participants(:three))

    assert_redirected_to new_user_session_path
  end

  test "new hides another user's participant" do
    sign_in users(:two)

    get new_participant_payment_path(participants(:one))

    assert_response :not_found
  end

  test "create redirects to the relevant Order without starting a separate payment" do
    participant = participants(:three)
    sign_in participant.user

    assert_no_difference("Payment.count") do
      post participant_payment_path(participant), params: { simulate_status: "paid" }
    end

    assert_redirected_to submitted_order_path(participant.order)
    assert_match "managed from your Order", flash[:notice]
  end

  test "create requires a signed-in owner" do
    participant = participants(:three)

    assert_no_difference("Payment.count") { post participant_payment_path(participant) }

    assert_redirected_to new_user_session_path
  end

  test "create hides another user's participant" do
    sign_in users(:two)

    post participant_payment_path(participants(:one))

    assert_response :not_found
  end

  test "create redirects visitors to participant page" do
    participant = participants(:one)
    participant.update!(participant_type: "visitor")

    post_payment(participant)

    assert_redirected_to participant_path(participant)
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

  test "success does not look up payments by their numeric id" do
    payment = payments(:open_payment)
    payment.update!(status: "failed")
    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| flunk "Mollie should not be called" }

    get success_payments_path(payment_id: payment.id)
    get success_payments_path(token: payment.id)

    assert_response :success
    assert_match "Return from Payment", response.body
    assert_no_match payment.participant.uuid, response.body
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  test "success ignores tampered and expired tokens" do
    payment = payments(:open_payment)
    payment.update!(status: "failed", mollie_payment_id: nil)
    token = payment.return_token

    get success_payments_path(token: "#{token}x")
    assert_match "Return from Payment", response.body

    travel Payment::RETURN_TOKEN_EXPIRY + 1.minute do
      get success_payments_path(token: token)
    end
    assert_match "Return from Payment", response.body
    assert_no_match payment.participant.uuid, response.body
  end

  test "success shows the payment for a valid token" do
    payment = payments(:open_payment)
    payment.update!(status: "failed", mollie_payment_id: nil)

    get success_payments_path(token: payment.return_token)

    assert_response :success
    assert_match "Payment Not Completed", response.body
    assert_select "a[href='#{submitted_order_path(payment.order)}']", text: "Try again"
  end

  test "success treats authorized payments as pending" do
    payment = payments(:open_payment)
    payment.update!(status: "authorized")
    mollie_stub = OpenStruct.new(id: payment.mollie_payment_id, status: "authorized")

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    get success_payments_path(token: payment.return_token)

    assert_response :success
    assert_match "Payment Pending", response.body
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  test "success offers to set a password when the signed-in user has none" do
    payment = payments(:paid_payment)
    payment.participant.update!(user: users(:no_password), email: users(:no_password).email)
    devise_sign_in users(:no_password)

    with_paid_mollie_stub(payment) do
      get success_payments_path(token: payment.return_token)
    end

    assert_response :success
    assert_match "Payment Successful", response.body
    assert_match "Set a password?", response.body
    assert_select "a[href='#{edit_user_registration_path}']", text: "Set a password"
    assert_select "form[action='#{skip_user_password_path}']"
  end

  test "success does not offer a password when paid payment belongs to another user" do
    payment = payments(:paid_payment)
    payment.participant.update!(user: users(:two), email: users(:two).email)
    devise_sign_in users(:no_password)

    with_paid_mollie_stub(payment) do
      get success_payments_path(token: payment.return_token)
    end

    assert_response :success
    assert_no_match "Set a password?", response.body
  end

  test "success does not offer a password when the signed-in user already has one" do
    payment = payments(:paid_payment)
    assert users(:two).password_set?, "fixture user should already have a password"
    sign_in users(:two)

    with_paid_mollie_stub(payment) do
      get success_payments_path(token: payment.return_token)
    end

    assert_response :success
    assert_no_match "Set a password?", response.body
  end

  test "success does not offer a password to anonymous visitors" do
    payment = payments(:paid_payment)

    with_paid_mollie_stub(payment) do
      get success_payments_path(token: payment.return_token)
    end

    assert_response :success
    assert_no_match "Set a password?", response.body
  end

  # webhook
  test "webhook asks Mollie to retry when fetching the payment fails" do
    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| raise Mollie::Exception, "not found" }

    post webhook_payments_path, params: { id: "tr_unknown" }

    assert_response :service_unavailable
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
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
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  test "webhook records the payment method reported by mollie" do
    payment = payments(:open_payment)
    mollie_stub = OpenStruct.new(
      id: payment.mollie_payment_id,
      status: "paid",
      attributes: { "method" => "ideal" }
    )

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    post webhook_payments_path, params: { id: payment.mollie_payment_id }

    assert_response :ok
    payment.reload
    assert_equal "paid", payment.status
    assert_equal "ideal", payment.payment_method
    assert_equal "mollie", payment.provider
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  test "webhook keeps the existing payment method when mollie reports none" do
    payment = payments(:open_payment)
    payment.update_columns(payment_method: "ideal")
    mollie_stub = OpenStruct.new(id: payment.mollie_payment_id, status: "paid")

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    post webhook_payments_path, params: { id: payment.mollie_payment_id }

    assert_response :ok
    assert_equal "ideal", payment.reload.payment_method
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  test "webhook records a refund while keeping the payment paid" do
    payment = payments(:paid_payment)
    mollie_stub = OpenStruct.new(
      id: payment.mollie_payment_id,
      status: "paid",
      amount_refunded: OpenStruct.new(value: BigDecimal("50.00"), currency: "EUR")
    )

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    post webhook_payments_path, params: { id: payment.mollie_payment_id }

    assert_response :ok
    payment.reload
    assert_equal "paid", payment.status
    assert payment.participant.reload.paid?
    assert_equal "Refund", payment.participant.registration_status
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  test "webhook records a chargeback while keeping the payment paid" do
    payment = payments(:paid_payment)
    mollie_stub = OpenStruct.new(
      id: payment.mollie_payment_id,
      status: "paid",
      amount_refunded: OpenStruct.new(value: BigDecimal("0.00"), currency: "EUR"),
      amount_charged_back: OpenStruct.new(value: BigDecimal("50.00"), currency: "EUR")
    )

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    post webhook_payments_path, params: { id: payment.mollie_payment_id }

    assert_response :ok
    payment.reload
    assert_equal "paid", payment.status
    assert payment.participant.reload.paid?
    assert_equal "Chargeback", payment.participant.registration_status
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  test "webhook keeps a payment paid when nothing was refunded" do
    payment = payments(:open_payment)
    mollie_stub = OpenStruct.new(
      id: payment.mollie_payment_id,
      status: "paid",
      amount_refunded: OpenStruct.new(value: BigDecimal("0.00"), currency: "EUR")
    )

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    post webhook_payments_path, params: { id: payment.mollie_payment_id }

    assert_response :ok
    assert_equal "paid", payment.reload.status
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  test "webhook is not blocked for outdated browser user agents" do
    payment = payments(:open_payment)
    mollie_stub = OpenStruct.new(id: payment.mollie_payment_id, status: "paid")

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    outdated_browser_user_agent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " \
      "(KHTML, like Gecko) Chrome/90.0.4430.93 Safari/537.36"

    assert_emails 1 do
      post webhook_payments_path,
        params: { id: payment.mollie_payment_id },
        headers: { "HTTP_USER_AGENT" => outdated_browser_user_agent }
    end

    assert_response :ok
    assert_equal "paid", payment.reload.status
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  private

  # Stubs Mollie::Payment.get so the success action can refresh the payment
  # status without making a network call, returning the payment as paid.
  def with_paid_mollie_stub(payment)
    mollie_stub = OpenStruct.new(id: payment.mollie_payment_id, status: "paid")
    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }
    yield
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end
end
