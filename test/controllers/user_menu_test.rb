require "test_helper"

class UserMenuTest < ActionDispatch::IntegrationTest
  test "account dropdown shows items from the user menu" do
    sign_in users(:one)
    get root_path

    assert_response :success
    assert_select "#user-menu a[href='/player-information']", text: menu_items(:user_dropdown_item).label
  end

  test "account dropdown hides invisible user menu items" do
    sign_in users(:one)
    get root_path

    assert_response :success
    assert_select "#user-menu a[href='/hidden-user-link']", count: 0
  end

  test "user menu items are not rendered for visitors" do
    get root_path

    assert_response :success
    assert_select "a[href='/player-information']", count: 0
  end

  test "user menu items are hidden when the menu is inactive" do
    menus(:user_dropdown).update!(active: false)

    sign_in users(:one)
    get root_path

    assert_response :success
    assert_select "#user-menu a[href='/player-information']", count: 0
  end
end
