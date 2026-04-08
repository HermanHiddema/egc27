require "test_helper"

class Users::MagicLinksControllerTest < ActionDispatch::IntegrationTest
  test "new renders the magic link request form" do
    get new_user_magic_link_session_path

    assert_response :success
    assert_select "form"
  end

  test "create redirects with notice for a known email" do
    user = users(:one)

    assert_emails 1 do
      post user_magic_link_session_path, params: { user: { email: user.email } }
    end

    assert_redirected_to new_user_session_path
    assert_match "you will receive a magic link", flash[:notice]
  end

  test "create redirects with same notice for an unknown email (no enumeration)" do
    assert_emails 0 do
      post user_magic_link_session_path, params: { user: { email: "nobody@example.com" } }
    end

    assert_redirected_to new_user_session_path
    assert_match "you will receive a magic link", flash[:notice]
  end

  test "rejects magic link request when turnstile verification fails" do
    fake_service = Object.new
    def fake_service.verify(**) = false

    CloudflareTurnstileService.stub(:new, fake_service) do
      post user_magic_link_session_path, params: { user: { email: users(:one).email } }
    end

    assert_response :unprocessable_entity
  end
end
