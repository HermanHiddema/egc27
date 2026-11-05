require "test_helper"

class DashboardAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access dashboard" do
    sign_in users(:one)
    get dashboard_path
    assert_redirected_to root_path
  end

  test "editor can access dashboard with allowed links only" do
    sign_in users(:editor)
    get dashboard_path

    assert_response :success
    assert_select "section[aria-labelledby=site-content-heading] a[href='#{pages_path}']", text: "Pages"
    assert_select "section[aria-labelledby=site-content-heading] a[href='#{admin_articles_path}']", text: "Articles"
    assert_select "section[aria-labelledby=communication-heading] a[href='#{notices_path}']", text: "Notices"
    assert_select "section[aria-labelledby=communication-heading] a[href='#{newsletter_signup_path}']", text: "Newsletters"
    assert_select "section[aria-labelledby=financial-heading]", count: 0
    assert_select "section[aria-labelledby=site-structure-heading]", count: 0
    assert_select "section[aria-labelledby=people-heading]", count: 0
    assert_select "a[href='#{admin_hostel_bookings_path}']", count: 0
    assert_select "a[href='#{users_path}']", count: 0
    assert_select "a[href='#{admin_participants_path}']", count: 0
    assert_select "a[href='#{admin_payments_path}']", count: 0
    assert_select "a[href='#{event_groups_path}']", count: 0
    assert_select "a[href='#{menus_path}']", count: 0
    assert_select "a[href='#{newsletter_subscriptions_path}']", count: 0
    assert_select "a[href='#{sponsors_path}']", count: 0
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
    assert_select "a[href='#{admin_payments_path}']", text: "Payments"
    assert_select "a[href='#{pages_path}']", text: "Pages"
    assert_select "a[href='#{event_groups_path}']", text: "Event Groups"
    assert_select "a[href='#{notices_path}']", text: "Notices"
    assert_select "a[href='#{menus_path}']", text: "Menus"
    assert_select "a[href='#{newsletter_subscriptions_path}']", text: "Newsletter subscriptions"
    assert_select "a[href='#{sponsors_path}']", text: "Sponsors"
    assert_select "section[aria-labelledby=people-heading] h2", text: "People"
    {
      "site-content" => [pages_path, admin_articles_path, event_groups_path, sponsors_path],
      "financial" => [admin_payments_path, admin_settlements_path],
      "site-structure" => [menus_path],
      "people" => [users_path, admin_participants_path, admin_hostel_bookings_path],
      "communication" => [notices_path, newsletter_signup_path, newsletter_subscriptions_path]
    }.each do |section, paths|
      paths.each do |path|
        assert_select "section[aria-labelledby=#{section}-heading] a[href='#{path}']", count: 1
      end
    end
  end
end
