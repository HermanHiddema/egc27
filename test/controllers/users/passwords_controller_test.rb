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
