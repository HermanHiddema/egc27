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

  test "editor cannot access new user page" do
    sign_in users(:editor)
    get new_user_path
    assert_redirected_to root_path
  end

  test "editor cannot create user" do
    sign_in users(:editor)

    assert_no_difference "User.count" do
      post create_user_path, params: {
        user: {
          email: "created-by-editor@example.com",
          full_name: "Editor Created User",
          role: "regular",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

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
    assert users(:one).valid_password?("password123")
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

  test "admin can change another user's role" do
    sign_in users(:admin)
    patch user_path(users(:one)), params: { user: { role: "editor" } }

    assert_redirected_to users_path
    assert_equal "editor", users(:one).reload.role
  end

  test "admin can access new user page" do
    sign_in users(:admin)
    get new_user_path
    assert_response :success
    assert_select "h1", text: "New User"
  end

  test "admin can create user" do
    sign_in users(:admin)

    assert_difference "User.count", 1 do
      post create_user_path, params: {
        user: {
          email: "created-by-admin@example.com",
          full_name: "Admin Created User",
          role: "editor",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to users_path
    user = User.find_by!(email: "created-by-admin@example.com")
    assert_equal "Admin Created User", user.full_name
    assert_equal "editor", user.role
  end

  test "admin cannot remove own admin role" do
    sign_in users(:admin)
    patch user_path(users(:admin)), params: { user: { role: "regular" } }

    assert_response :unprocessable_entity
    assert_equal "admin", users(:admin).reload.role
    assert_match "cannot be changed for your own account", response.body
  end
end
