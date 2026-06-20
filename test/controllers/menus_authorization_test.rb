require "test_helper"

class MenusAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access menus index" do
    sign_in users(:one)
    get menus_path
    assert_redirected_to root_path
  end

  test "editor cannot access menus index" do
    sign_in users(:editor)
    get menus_path
    assert_redirected_to root_path
  end

  test "regular user cannot access new menu" do
    sign_in users(:one)
    get new_menu_path
    assert_redirected_to root_path
  end

  test "regular user cannot create menu" do
    sign_in users(:one)
    assert_no_difference "Menu.count" do
      post menus_path, params: { menu: { name: "Test Menu", location: "sidebar", active: true } }
    end
    assert_redirected_to root_path
  end

  test "regular user cannot edit menu" do
    sign_in users(:one)
    get edit_menu_path(menus(:primary))
    assert_redirected_to root_path
  end

  test "regular user cannot update menu" do
    sign_in users(:one)
    patch menu_path(menus(:primary)), params: { menu: { name: "Changed" } }
    assert_redirected_to root_path
    assert_equal menus(:primary).name, menus(:primary).reload.name
  end

  test "regular user does not see menu management buttons" do
    sign_in users(:one)

    get menu_path(menus(:primary))
    assert_response :success
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0
  end

  test "editor sees menu edit button but not delete on menu show" do
    sign_in users(:editor)

    get menu_path(menus(:primary))
    assert_response :success
    assert_select "a[href='#{edit_menu_path(menus(:primary))}']", text: "Edit", count: 1
    assert_select "form[action='#{menu_path(menus(:primary))}'] button", text: "Delete", count: 0
  end

  test "admin sees menu delete button on menu show" do
    sign_in users(:admin)

    get menu_path(menus(:primary))
    assert_response :success
    assert_select "form[action='#{menu_path(menus(:primary))}'] button", text: "Delete"
  end

  test "regular user cannot destroy menu" do
    sign_in users(:one)
    assert_no_difference "Menu.count" do
      delete menu_path(menus(:primary))
    end
    assert_redirected_to root_path
    assert Menu.exists?(menus(:primary).id)
  end

  test "editor can access new menu" do
    sign_in users(:editor)
    get new_menu_path
    assert_response :success
  end

  test "editor can create menu" do
    sign_in users(:editor)
    assert_difference "Menu.count", 1 do
      post menus_path, params: { menu: { name: "Test Menu", location: "sidebar", active: true } }
    end
  end

  test "editor can edit menu" do
    sign_in users(:editor)
    get edit_menu_path(menus(:primary))
    assert_response :success
  end

  test "editor cannot destroy menu" do
    sign_in users(:editor)
    assert_no_difference "Menu.count" do
      delete menu_path(menus(:primary))
    end
    assert_redirected_to root_path
    assert Menu.exists?(menus(:primary).id)
  end

  test "admin can access new menu" do
    sign_in users(:admin)
    get new_menu_path
    assert_response :success
  end

  test "admin can edit menu" do
    sign_in users(:admin)
    get edit_menu_path(menus(:primary))
    assert_response :success
  end

  test "admin can destroy menu" do
    sign_in users(:admin)
    assert_difference "Menu.count", -1 do
      delete menu_path(menus(:primary))
    end
    assert_redirected_to menus_path
    refute Menu.exists?(menus(:primary).id)
  end
end
