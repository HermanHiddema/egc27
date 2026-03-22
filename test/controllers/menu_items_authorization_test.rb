require "test_helper"

class MenuItemsAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access new menu item" do
    sign_in users(:one)
    get new_menu_menu_item_path(menus(:primary))
    assert_redirected_to root_path
  end

  test "regular user cannot create menu item" do
    sign_in users(:one)
    assert_no_difference "MenuItem.count" do
      post menu_menu_items_path(menus(:primary)), params: {
        menu_item: { label: "New Item", url: "https://example.com", position: 10, visible: true, open_in_new_tab: false }
      }
    end
    assert_redirected_to root_path
  end

  test "regular user cannot edit menu item" do
    sign_in users(:one)
    get edit_menu_menu_item_path(menus(:primary), menu_items(:schedule))
    assert_redirected_to root_path
  end

  test "regular user cannot update menu item" do
    sign_in users(:one)
    patch menu_menu_item_path(menus(:primary), menu_items(:schedule)), params: {
      menu_item: { label: "Changed" }
    }
    assert_redirected_to root_path
    assert_equal menu_items(:schedule).label, menu_items(:schedule).reload.label
  end

  test "editor can access new menu item" do
    sign_in users(:editor)
    get new_menu_menu_item_path(menus(:primary))
    assert_response :success
  end

  test "editor can create menu item" do
    sign_in users(:editor)
    assert_difference "MenuItem.count", 1 do
      post menu_menu_items_path(menus(:primary)), params: {
        menu_item: { label: "New Item", url: "https://example.com", position: 10, visible: true, open_in_new_tab: false }
      }
    end
  end

  test "editor can edit menu item" do
    sign_in users(:editor)
    get edit_menu_menu_item_path(menus(:primary), menu_items(:schedule))
    assert_response :success
  end

  test "editor cannot destroy menu item" do
    sign_in users(:editor)
    assert_no_difference "MenuItem.count" do
      delete menu_menu_item_path(menus(:primary), menu_items(:schedule))
    end
    assert_redirected_to root_path
    assert MenuItem.exists?(menu_items(:schedule).id)
  end

  test "admin can access new menu item" do
    sign_in users(:admin)
    get new_menu_menu_item_path(menus(:primary))
    assert_response :success
  end

  test "admin can edit menu item" do
    sign_in users(:admin)
    get edit_menu_menu_item_path(menus(:primary), menu_items(:schedule))
    assert_response :success
  end

  test "admin can destroy menu item" do
    sign_in users(:admin)
    assert_difference "MenuItem.count", -1 do
      delete menu_menu_item_path(menus(:primary), menu_items(:schedule))
    end
    assert_redirected_to menu_menu_items_path(menus(:primary))
    refute MenuItem.exists?(menu_items(:schedule).id)
  end
end
