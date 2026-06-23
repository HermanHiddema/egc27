require "test_helper"

class DeviseViewsTest < ActionDispatch::IntegrationTest
  test "sign in page renders with site styling" do
    get new_user_session_path

    assert_response :success
    assert_select "div.card-elevated"
    assert_select "h1", text: "Sign in to your account"
    assert_select "input#user_email"
    assert_select "input#user_password"
    assert_select "button", text: "Sign in"
  end

  test "sign up page renders with site styling" do
    get new_user_registration_path

    assert_response :success
    assert_select "div.card-elevated"
    assert_select "h1", text: "Create your account"
    assert_select "input[name='user[full_name]']"
    assert_select "input[name='user[email]']"
  end

  test "forgot password page renders with site styling" do
    get new_user_password_path

    assert_response :success
    assert_select "div.card-elevated"
    assert_select "h1", text: "Forgot your password?"
    assert_select "input[name='user[email]']"
  end

  test "reset password page renders with site styling" do
    get edit_user_password_path(reset_password_token: "abcdef")

    assert_response :success
    assert_select "div.card-elevated"
    assert_select "h1", text: "Change your password"
    assert_select "input[name='user[reset_password_token]']"
  end

  test "resend confirmation page renders with site styling" do
    get new_user_confirmation_path

    assert_response :success
    assert_select "div.card-elevated"
    assert_select "h1", text: "Resend confirmation instructions"
    assert_select "input[name='user[email]']"
  end

  test "magic link request page renders with site styling" do
    get new_user_magic_link_session_path

    assert_response :success
    assert_select "div.card-elevated"
    assert_select "h1", text: "Sign in with a magic link"
    assert_select "input#user_email"
  end
end
