require "test_helper"

class AccountManagementTest < ActionDispatch::IntegrationTest
  test "regular user sees account links in username dropdown" do
    sign_in users(:one)

    get root_path
    assert_response :success
    assert_select "button", text: /#{Regexp.escape(users(:one).display_name)}/
    assert_select "a", text: "Account"
    assert_select "a", text: "Users", count: 0
    assert_select "button", text: "Sign out"
  end

  test "user can edit account page and update display name email and password" do
    sign_in users(:one)

    get edit_user_registration_path
    assert_response :success
    assert_select "button", text: /#{Regexp.escape(users(:one).display_name)}/
    assert_select "a", text: "Account"
    assert_select "h1", text: "Edit Account"
    assert_select "input[name='user[full_name]']"

    patch user_registration_path, params: {
      user: {
        full_name: "Updated Display Name",
        email: "updated@example.com",
        password: "newpassword123",
        password_confirmation: "newpassword123",
        current_password: "password123"
      }
    }

    assert_response :redirect
    updated_user = users(:one).reload
    assert_equal "Updated Display Name", updated_user.full_name
    assert_equal "updated@example.com", updated_user.unconfirmed_email
    assert updated_user.valid_password?("newpassword123")
  end
end
