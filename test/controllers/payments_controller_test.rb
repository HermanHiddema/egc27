require "test_helper"
require "ostruct"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include ActiveSupport::Testing::TimeHelpers

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

    travel_to Time.zone.local(2026, 8, 1) do
      get new_participant_payment_path(participant)
    end

    assert_response :success
    assert_match "This price is valid until", response.body
    assert_match "31 Aug 2026", response.body
    assert_match "After that, the price will go up.", response.body
    assert_match "If none of the payment options offered by Mollie work for you, please contact us to discuss other payment options.", response.body
  end

  test "new reuses an in-progress payment for pricing and display" do
    participant = participants(:three)
    payment = participant.payments.create!(
      amount_cents: 12_345,
      description: "Existing pending payment",
      status: "pending",
      created_at: Time.zone.local(2026, 8, 15),
      updated_at: Time.zone.local(2026, 8, 15)
    )

    travel_to Time.zone.local(2026, 9, 10) do
      get new_participant_payment_path(participant)
    end

    assert_response :success
    assert_match payment.description, response.body
    assert_match "31 Aug 2026", response.body
  end

  test "new does not show price validity notice in final pricing period" do
    participant = participants(:three)

    travel_to Time.zone.local(2027, 6, 1) do
      get new_participant_payment_path(participant)
    end

    assert_response :success
    assert_no_match "This price is valid until", response.body
    assert_no_match "After that, the price will go up.", response.body
  end

  test "new uses persisted payment date for price validity text" do
    participant = participants(:one)
    payment = payments(:open_payment)
    payment.update!(
      participant: participant,
      amount_cents: 19_000,
      description: "EGC 2027 Congress Pass – Full (Week 1 + Weekend + Week 2)",
      status: "pending",
      created_at: Time.zone.local(2026, 8, 15)
    )

    travel_to Time.zone.local(2026, 9, 10) do
      get new_participant_payment_path(participant)
    end

    assert_response :success
    assert_match "This price is valid until", response.body
    assert_match "31 Aug 2026", response.body
  end

  test "new hides Mollie simulation controls outside development and test environments" do
    participant = participants(:one)

    with_mollie_simulation_enabled do
      with_rails_env("production") do
        get new_participant_payment_path(participant)
      end
    end

    assert_response :success
    assert_no_match "Development: Simulate Mollie Response", response.body
  end

  test "new shows paid state for participant with completed payment" do
    participant = participants(:two)

    get new_participant_payment_path(participant)

    assert_response :success
    assert_match "already been paid", response.body
    assert_no_match "This price is valid until", response.body
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

  test "create starts a single payment when no in-progress payment exists" do
    participant = participants(:three)
    mollie_stub = OpenStruct.new(id: "tr_new_attempt_123", checkout_url: "https://example.test/new-checkout")

    original = Mollie::Payment.method(:create)
    Mollie::Payment.define_singleton_method(:create) { |**_params| mollie_stub }

    assert_difference("Payment.count", 1) do
      post participant_payment_path(participant)
    end

    assert_redirected_to "https://example.test/new-checkout"
    assert_equal "tr_new_attempt_123", participant.payments.order(created_at: :desc).first.mollie_payment_id
  ensure
    Mollie::Payment.define_singleton_method(:create, &original)
  end

  test "create keeps confirmed payment view state when mollie creation fails" do
    participant = participants(:three)

    original = Mollie::Payment.method(:create)
    Mollie::Payment.define_singleton_method(:create) { |**_params| raise Mollie::Exception, "boom" }

    post participant_payment_path(participant)

    assert_response :unprocessable_entity
    assert_match "Payment could not be started: boom", response.body
    assert_no_match "Please confirm your email address", response.body
  ensure
    Mollie::Payment.define_singleton_method(:create, &original)
  end

  test "create reuses the latest in-progress payment" do
    payment = payments(:open_payment)
    mollie_stub = OpenStruct.new(id: payment.mollie_payment_id, status: "open", checkout_url: "https://example.test/mollie-checkout")

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    assert_no_difference("Payment.count") do
      post participant_payment_path(payment.participant)
    end

    assert_redirected_to "https://example.test/mollie-checkout"
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  test "create redirects to success when mollie already marks the payment as paid" do
    payment = payments(:open_payment)
    mollie_stub = OpenStruct.new(id: payment.mollie_payment_id, status: "paid")

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    assert_no_difference("Payment.count") do
      post participant_payment_path(payment.participant)
    end

    assert_equal "paid", payment.reload.status
    assert_redirected_to success_payments_path
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  test "create starts a new payment attempt when previous mollie checkout is unavailable" do
    payment = payments(:open_payment)
    stale_mollie = OpenStruct.new(id: payment.mollie_payment_id, status: "failed", checkout_url: nil)
    new_mollie = OpenStruct.new(id: "tr_new_attempt_123", checkout_url: "https://example.test/new-checkout")

    original_get = Mollie::Payment.method(:get)
    original_create = Mollie::Payment.method(:create)
    Mollie::Payment.define_singleton_method(:get) { |_id| stale_mollie }
    Mollie::Payment.define_singleton_method(:create) { |**_params| new_mollie }

    assert_difference("Payment.count", 1) do
      post participant_payment_path(payment.participant)
    end

    assert_redirected_to "https://example.test/new-checkout"
    assert_equal "failed", payment.reload.status
    assert_equal "tr_new_attempt_123", payment.participant.payments.order(created_at: :desc).first.mollie_payment_id
  ensure
    Mollie::Payment.define_singleton_method(:get, &original_get)
    Mollie::Payment.define_singleton_method(:create, &original_create)
  end

  test "create can simulate a paid Mollie status when enabled" do
    participant = participants(:three)

    with_mollie_simulation_enabled do
      assert_difference("Payment.count", 1) do
        post participant_payment_path(participant), params: { simulate_status: "paid" }
      end
    end

    payment = participant.payments.order(created_at: :desc).first
    assert_redirected_to success_payments_path(payment_id: payment.id)
    assert_equal "paid", payment.status
    assert_nil payment.mollie_payment_id
  end

  test "create can simulate failed status on an existing in-progress payment" do
    payment = payments(:open_payment)

    with_mollie_simulation_enabled do
      assert_no_difference("Payment.count") do
        post participant_payment_path(payment.participant), params: { simulate_status: "failed" }
      end
    end

    assert_redirected_to success_payments_path(payment_id: payment.id)
    assert_equal "failed", payment.reload.status
    assert_nil payment.mollie_payment_id
  end

  test "create ignores simulate_status outside development and test environments" do
    participant = participants(:three)
    mollie_stub = OpenStruct.new(id: "tr_live_123", checkout_url: "https://example.test/live-checkout")
    original = Mollie::Payment.method(:create)
    Mollie::Payment.define_singleton_method(:create) { |**_params| mollie_stub }

    with_mollie_simulation_enabled do
      with_rails_env("production") do
        post participant_payment_path(participant), params: { simulate_status: "paid" }
      end
    end

    payment = participant.payments.order(created_at: :desc).first
    assert_redirected_to "https://example.test/live-checkout"
    assert_equal "open", payment.status
    assert_equal "tr_live_123", payment.mollie_payment_id
  ensure
    Mollie::Payment.define_singleton_method(:create, &original)
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
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  test "success offers to set a password when the signed-in user has none" do
    payment = payments(:paid_payment)
    payment.participant.update!(user: users(:no_password), email: users(:no_password).email)
    devise_sign_in users(:no_password)

    with_paid_mollie_stub(payment) do
      get success_payments_path(payment_id: payment.id)
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
      get success_payments_path(payment_id: payment.id)
    end

    assert_response :success
    assert_no_match "Set a password?", response.body
  end

  test "success does not offer a password when the signed-in user already has one" do
    payment = payments(:paid_payment)
    assert users(:two).password_set?, "fixture user should already have a password"
    sign_in users(:two)

    with_paid_mollie_stub(payment) do
      get success_payments_path(payment_id: payment.id)
    end

    assert_response :success
    assert_no_match "Set a password?", response.body
  end

  test "success does not offer a password to anonymous visitors" do
    payment = payments(:paid_payment)

    with_paid_mollie_stub(payment) do
      get success_payments_path(payment_id: payment.id)
    end

    assert_response :success
    assert_no_match "Set a password?", response.body
  end

  # webhook
  test "webhook returns ok on unknown mollie id" do
    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| raise Mollie::Exception, "not found" }

    post webhook_payments_path, params: { id: "tr_unknown" }

    assert_response :ok
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

  test "webhook is not blocked by the modern browser guard" do
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

  def with_mollie_simulation_enabled
    original = Rails.application.config.x.payments.simulate_mollie
    Rails.application.config.x.payments.simulate_mollie = true
    yield
  ensure
    Rails.application.config.x.payments.simulate_mollie = original
  end

  # Temporarily switches Rails.env for the duration of the block so environment
  # guards (e.g. the dev/test-only Mollie simulation path) can be exercised.
  def with_rails_env(env_name)
    original = Rails.method(:env).to_proc
    Rails.define_singleton_method(:env) { ActiveSupport::EnvironmentInquirer.new(env_name) }
    yield
  ensure
    Rails.define_singleton_method(:env, &original)
  end
end
