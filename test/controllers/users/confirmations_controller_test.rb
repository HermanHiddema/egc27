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
end
