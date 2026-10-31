require "test_helper"

class Users::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test "new renders the resend confirmation form with the turnstile widget when configured" do
    with_turnstile_configured do
      get new_user_confirmation_path

      assert_response :success
      assert_select "div.cf-turnstile"
    end
  end

  test "rejects confirmation resend when turnstile verification fails" do
    with_turnstile_configured do
      assert_emails 0 do
        # deliberately omitting cf-turnstile-response so the token is blank → verify returns false
        post user_confirmation_path, params: { user: { email: "unconfirmed@example.com" } }
      end

      assert_response :unprocessable_entity
    end
  end

  test "a confirmation link expires after two weeks" do
    user = users(:one)
    raw_token, hashed_token = Devise.token_generator.generate(User, :confirmation_token)
    user.update!(confirmed_at: nil, confirmation_token: hashed_token, confirmation_sent_at: 2.weeks.ago - 1.second)

    get user_confirmation_path, params: { confirmation_token: raw_token }

    assert_response :success
    refute user.reload.confirmed?
  end

  test "a confirmation link can only be used once" do
    user = users(:one)
    raw_token, hashed_token = Devise.token_generator.generate(User, :confirmation_token)
    user.update!(confirmed_at: nil, confirmation_token: hashed_token, confirmation_sent_at: Time.current)

    get user_confirmation_path, params: { confirmation_token: raw_token }
    assert_redirected_to edit_user_registration_path
    assert user.reload.confirmed?
    assert_nil user.confirmation_token

    get user_confirmation_path, params: { confirmation_token: raw_token }
    assert_response :success
    assert_match "Confirmation token is invalid", response.body
    assert user.reload.confirmed?
  end
end
