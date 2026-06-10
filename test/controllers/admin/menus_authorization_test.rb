require "test_helper"

class Admin::MenusAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access admin dashboard" do
    sign_in users(:one)
    get admin_root_path
    assert_redirected_to root_path
  end

  test "editor cannot access admin menus" do
    sign_in users(:editor)
    get admin_menus_path
    assert_redirected_to root_path
  end

  test "admin can access admin menus and edit links" do
    sign_in users(:admin)
    get admin_menus_path
    assert_response :success

    assert_select "a[href='#{edit_menu_path(menus(:primary))}']"
    assert_select "a[href='#{menu_menu_items_path(menus(:primary))}']"
  end

  test "admin dashboard links to users page" do
    sign_in users(:admin)
    get admin_root_path

    assert_response :success
    assert_select "a[href='#{users_path}']", text: "Users"
  end
end
