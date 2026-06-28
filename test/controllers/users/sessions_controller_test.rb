require "test_helper"

class Users::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new renders the sign in form with the turnstile widget when configured" do
    with_turnstile_configured do
      get new_user_session_path

      assert_response :success
      assert_select "div.cf-turnstile"
    end
  end

  test "rejects sign in when turnstile verification fails" do
    with_turnstile_configured do
      # deliberately omitting cf-turnstile-response so the token is blank → verify returns false
      post user_session_path, params: { user: { email: users(:one).email, password: "password123" } }

      assert_response :unprocessable_entity
      assert_nil session["warden.user.user.key"]
    end
  end

  test "signs in successfully when turnstile is not configured" do
    post user_session_path, params: { user: { email: users(:one).email, password: "password123" } }

    assert_redirected_to mine_participants_path
  end
end
