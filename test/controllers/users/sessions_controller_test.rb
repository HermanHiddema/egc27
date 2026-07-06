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

  test "shows an error when the password is wrong" do
    post user_session_path, params: { user: { email: users(:one).email, password: "wrong-password" } }

    # Turbo only renders form responses that redirect or signal an error, so the
    # failed sign in must respond with :unprocessable_entity for the message to appear.
    assert_response :unprocessable_entity
    assert_nil session["warden.user.user.key"]
    assert_select "div.bg-red-50", text: /Invalid email or password/i
  end

  test "shows an error when the email does not exist" do
    post user_session_path, params: { user: { email: "nobody@example.com", password: "whatever" } }

    assert_response :unprocessable_entity
    assert_nil session["warden.user.user.key"]
    assert_select "div.bg-red-50", text: /Invalid email or password/i
  end
end
