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
end
