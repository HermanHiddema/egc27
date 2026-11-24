require "application_system_test_case"

class AdminFilterDropdownTest < ApplicationSystemTestCase
  test "filter menus close on outside clicks and preserve checkbox selections" do
    visit new_user_session_path
    fill_in "user_email", with: users(:admin).email
    fill_in "user_password", with: "password123"
    click_button "Sign in"
    assert_selector "button[aria-controls='user-menu']"

    visit admin_hostel_bookings_path
    menu = find("details", text: "Payment status")
    menu.find("summary").click
    assert_selector "details[open]", text: "Payment status"
    check "Paid"
    find("h1", text: "Hostel bookings").click
    assert_no_selector "details[open]", text: "Payment status"
    menu.find("summary").click
    assert_checked_field "Paid"
    select "Active orders", from: "Order status"
    assert_selector "select[name='order_status'] option[value='active']:checked"
    assert_checked_field "Paid", visible: :all

    visit admin_participants_path
    find("details", text: "Participant status").find("summary").click
    assert_selector "details[open]", text: "Participant status"
    find("h1").click
    assert_no_selector "details[open]", text: "Participant status"

    visit admin_orders_path
    find("details", text: "Order/payment status").find("summary").click
    assert_selector "details[open]", text: "Order/payment status"
    find("h1").click
    assert_no_selector "details[open]", text: "Order/payment status"
  end
end
