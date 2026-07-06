require "test_helper"

class UsersAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access users index" do
    sign_in users(:one)
    get users_path
    assert_redirected_to root_path
  end

  test "regular user cannot edit another user" do
    sign_in users(:one)
    get edit_user_path(users(:editor))
    assert_redirected_to root_path
  end

  test "editor cannot see users index" do
    sign_in users(:editor)
    get users_path
    assert_redirected_to root_path
  end

  test "editor cannot update user details" do
    sign_in users(:editor)
    patch user_path(users(:one)), params: {
      user: {
        full_name: "Updated Name",
        role: "admin"
      }
    }

    assert_redirected_to root_path
    assert_nil users(:one).reload.full_name
  end

  test "editor cannot update another user's password" do
    sign_in users(:editor)

    patch user_path(users(:one)), params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to root_path
    assert users(:one).reload.valid_password?("password123")
  end

  test "editor cannot access user edit form" do
    sign_in users(:editor)

    get edit_user_path(users(:one))

    assert_redirected_to root_path
  end

  test "admin can update another user's password" do
    sign_in users(:admin)

    patch user_path(users(:one)), params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to users_path
    assert users(:one).reload.valid_password?("newpassword123")
  end

  test "admin cannot update password when confirmation does not match" do
    sign_in users(:admin)

    patch user_path(users(:one)), params: {
      user: {
        password: "newpassword123",
        password_confirmation: "differentpassword123"
      }
    }

    assert_response :unprocessable_entity
    assert users(:one).reload.valid_password?("password123")
    assert_match "Password confirmation", response.body
  end

  test "admin can change another user's role" do
    sign_in users(:admin)
    patch user_path(users(:one)), params: { user: { role: "editor" } }

    assert_redirected_to users_path
    assert_equal "editor", users(:one).reload.role
  end

  test "admin cannot remove own admin role" do
    sign_in users(:admin)
    patch user_path(users(:admin)), params: { user: { role: "regular" } }

    assert_response :unprocessable_entity
    assert_equal "admin", users(:admin).reload.role
    assert_match "cannot be changed for your own account", response.body
  end

  test "admin can access invite user page" do
    sign_in users(:admin)
    get invite_user_path
    assert_response :success
    assert_select "h1", text: "Invite User"
  end

  test "editor cannot access invite user page" do
    sign_in users(:editor)
    get invite_user_path
    assert_redirected_to root_path
  end

  test "admin can invite a user without a password and an invitation email is sent" do
    sign_in users(:admin)

    assert_difference "User.count", 1 do
      assert_emails 1 do
        post send_invitation_user_path, params: {
          user: {
            email: "invited@example.com",
            full_name: "Invited User",
            role: "editor"
          }
        }
      end
    end

    assert_redirected_to users_path
    user = User.find_by!(email: "invited@example.com")
    assert_equal "Invited User", user.full_name
    assert_equal "editor", user.role
    assert_not user.password_set?
    assert_nil user.confirmed_at
  end

  test "editor cannot invite a user" do
    sign_in users(:editor)

    assert_no_difference "User.count" do
      post send_invitation_user_path, params: {
        user: {
          email: "invited-by-editor@example.com",
          full_name: "Invited User",
          role: "regular"
        }
      }
    end

    assert_redirected_to root_path
  end

  test "invite with invalid email re-renders the form" do
    sign_in users(:admin)

    assert_no_difference "User.count" do
      post send_invitation_user_path, params: {
        user: {
          email: "",
          full_name: "No Email"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "h1", text: "Invite User"
  end
end
