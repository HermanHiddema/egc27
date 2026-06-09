require "test_helper"

class AccountManagementTest < ActionDispatch::IntegrationTest
  test "regular user sees account links in username dropdown" do
    sign_in users(:one)

    get root_path
    assert_response :success
    assert_select "button[aria-controls='user-menu'][aria-expanded='false'][aria-haspopup='true']", text: users(:one).display_name
    assert_select "a", text: "Account"
    assert_select "a", text: "Admin", count: 0
    assert_select "a", text: "Users", count: 0
    assert_select "button", text: "Sign out"
  end

  test "admin sees admin link in username dropdown" do
    sign_in users(:admin)

    get root_path
    assert_response :success
    assert_select "button[aria-controls='user-menu'][aria-expanded='false'][aria-haspopup='true']", text: users(:admin).display_name
    assert_select "a[href='#{edit_user_registration_path}']", text: "Account"
    assert_select "a[href='#{admin_root_path}']", text: "Admin"
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

  test "passwordless user can set an initial password without current password" do
    user = User.create!(
      email: "passwordless@example.com",
      full_name: "Passwordless User",
      skip_password_validation: true,
      confirmed_at: Time.current
    )

    devise_sign_in user

    get edit_user_registration_path
    assert_response :success
    assert_select "input[name='user[current_password]']", count: 0
    assert_match "You do not have a password yet. Set one here to enable password sign-in.", response.body

    patch user_registration_path, params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_response :redirect
    assert user.reload.valid_password?("newpassword123")
  end
end
