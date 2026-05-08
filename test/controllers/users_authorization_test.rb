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

  test "editor can see users index" do
    sign_in users(:editor)
    get users_path
    assert_response :success
    assert_select "h1", text: "Users"
  end

  test "editor can update user details but not role" do
    sign_in users(:editor)
    patch user_path(users(:one)), params: {
      user: {
        full_name: "Updated Name",
        role: "admin"
      }
    }

    assert_redirected_to users_path
    updated_user = users(:one).reload
    assert_equal "Updated Name", updated_user.full_name
    assert_equal "regular", updated_user.role
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
end
