require "test_helper"

class AdminMenusAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access admin dashboard" do
    sign_in users(:one)
    get dashboard_path
    assert_redirected_to root_path
  end

  test "editor cannot access admin menus" do
    sign_in users(:editor)
    get menu_management_path
    assert_redirected_to root_path
  end

  test "admin can access admin menus and edit links" do
    sign_in users(:admin)
    get menu_management_path
    assert_response :success

    assert_select "a[href='#{edit_menu_path(menus(:primary))}']"
    assert_select "a[href='#{menu_menu_items_path(menus(:primary))}']"
  end

  test "admin dashboard links to users and sponsors pages" do
    sign_in users(:admin)
    get dashboard_path

    assert_response :success
    assert_select "a[href='#{users_path}']", text: "Users"
    assert_select "a[href='#{sponsors_path}']", text: "Sponsors"
  end
end
