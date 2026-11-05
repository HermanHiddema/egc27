require "test_helper"

class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "new renders the forgot password form with the turnstile widget when configured" do
    with_turnstile_configured do
      get new_user_password_path

      assert_response :success
      assert_select "div.cf-turnstile"
    end
  end

  test "rejects password reset request when turnstile verification fails" do
    with_turnstile_configured do
      assert_emails 0 do
        # deliberately omitting cf-turnstile-response so the token is blank → verify returns false
        post user_password_path, params: { user: { email: users(:one).email } }
      end

      assert_response :unprocessable_entity
    end
  end

  test "sends reset instructions when turnstile is not configured" do
    assert_emails 1 do
      post user_password_path, params: { user: { email: users(:one).email } }
    end

    assert_redirected_to new_user_session_path
  end

  test "reports an unknown email without sending instructions" do
    assert_emails 0 do
      post user_password_path, params: { user: { email: "unknown@example.org" } }
    end

    assert_response :unprocessable_entity
    assert_select "#error_explanation h2", text: "Unknown email address"
  end

  test "shows the account on the reset form and after a validation error" do
    user = users(:one)
    raw_token, hashed_token = Devise.token_generator.generate(User, :reset_password_token)
    user.update!(reset_password_token: hashed_token, reset_password_sent_at: Time.current)

    get edit_user_password_path(reset_password_token: raw_token)
    assert_response :success
    assert_select "strong", text: user.email

    put user_password_path, params: { user: { reset_password_token: raw_token, password: "short", password_confirmation: "short" } }
    assert_response :unprocessable_entity
    assert_select "strong", text: user.email
  end

  test "does not identify an account for an expired or invalid reset token" do
    user = users(:one)
    raw_token, hashed_token = Devise.token_generator.generate(User, :reset_password_token)
    user.update!(reset_password_token: hashed_token, reset_password_sent_at: 1.year.ago)

    [raw_token, "invalid-token"].each do |token|
      get edit_user_password_path(reset_password_token: token)
      assert_response :success
      assert_select "strong", text: user.email, count: 0
    end
  end

  test "a password reset link can only be used once" do
    user = users(:one)
    raw_token, hashed_token = Devise.token_generator.generate(User, :reset_password_token)
    user.update!(reset_password_token: hashed_token, reset_password_sent_at: Time.current)

    # First use: resets the password and consumes the token.
    put user_password_path, params: {
      user: {
        reset_password_token: raw_token,
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }
    assert_redirected_to mine_participants_path
    assert_nil user.reload.reset_password_token

    # Devise signs the user in after a successful reset; sign out so the reuse
    # attempt is evaluated purely on the (now consumed) token.
    delete destroy_user_session_path

    # Second use: the same link no longer resets the password. The re-rendered
    # form responds with :unprocessable_entity so Turbo shows the error.
    put user_password_path, params: {
      user: {
        reset_password_token: raw_token,
        password: "anotherpassword123",
        password_confirmation: "anotherpassword123"
      }
    }
    assert_response :unprocessable_entity
    assert user.reload.valid_password?("newpassword123")
    refute user.valid_password?("anotherpassword123")
  end
end
