require "test_helper"

class MagicLinkSignInTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "a magic link signs the user in once and is rejected on reuse" do
    token = @user.encode_passwordless_token

    # First use: signs the user in and redirects to the app.
    get user_magic_link_path(user: { email: @user.email, token: token })
    assert_redirected_to mine_participants_path
    follow_redirect!
    assert_response :success
    assert_nil @user.reload.magic_link_token

    # Sign out so we can attempt to reuse the link.
    delete destroy_user_session_path
    follow_redirect!

    # Second use: the same link no longer authenticates.
    get user_magic_link_path(user: { email: @user.email, token: token })
    follow_redirect! while response.redirect?
    assert_select "h1", text: "Sign in to your account"
  end
end
