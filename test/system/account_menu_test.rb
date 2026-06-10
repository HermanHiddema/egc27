require "application_system_test_case"

class AccountMenuTest < ApplicationSystemTestCase
  test "user can open account menu with a click" do
    visit new_user_session_path

    fill_in "user_email", with: users(:one).email
    fill_in "user_password", with: "password123"
    click_button "Sign in"

    menu_button = find("button[aria-controls='user-menu']")
    assert_equal "false", menu_button["aria-expanded"]

    menu_button.click

    assert_selector "#user-menu", visible: true
    assert_equal "true", find("button[aria-controls='user-menu']")["aria-expanded"]
  end
end
