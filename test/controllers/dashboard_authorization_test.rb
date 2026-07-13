require "test_helper"

class DashboardAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access dashboard" do
    sign_in users(:one)
    get dashboard_path
    assert_redirected_to root_path
  end

  test "admin can access menus index and management controls" do
    sign_in users(:admin)
    get menus_path
    assert_response :success

    assert_select "a[href='#{new_menu_path}']", text: "New Menu"
    assert_select "a[href='#{edit_menu_path(menus(:primary))}']", text: "Edit"
    assert_select "a[href='#{menu_menu_items_path(menus(:primary))}']", text: "Items"
    assert_select "form[action='#{menu_path(menus(:primary))}'] button", text: "Delete"
  end

  test "admin dashboard links to users and sponsors pages" do
    sign_in users(:admin)
    get dashboard_path

    assert_response :success
    assert_select "a[href='#{users_path}']", text: "Users"
    assert_select "a[href='#{admin_participants_path}']", text: "Participants"
    assert_select "a[href='#{notices_path}']", text: "Notices"
    assert_select "a[href='#{menus_path}']", text: "Menus"
    assert_select "a[href='#{admin_sponsors_path}']", text: "Sponsors"
  end
end
