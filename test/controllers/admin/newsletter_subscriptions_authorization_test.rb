require "test_helper"

class AdminNewsletterSubscriptionsAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access admin newsletter subscriptions" do
    sign_in users(:one)
    get newsletter_subscriptions_path
    assert_redirected_to root_path
  end

  test "admin can list newsletter subscriptions" do
    sign_in users(:admin)
    get newsletter_subscriptions_path
    assert_response :success
    assert_select "h1", text: "Newsletter Subscriptions"
    assert_select "td", text: newsletter_subscriptions(:active).email
  end

  test "admin can access edit page for a subscription" do
    sign_in users(:admin)
    get edit_newsletter_subscription_path(newsletter_subscriptions(:active))
    assert_response :success
    assert_select "h1", text: "Edit Subscription"
  end

  test "admin can update a newsletter subscription" do
    sign_in users(:admin)
    subscription = newsletter_subscriptions(:active)

    patch newsletter_subscription_path(subscription), params: {
      newsletter_subscription: {
        first_name: "Updated",
        last_name: "Name",
        email: subscription.email,
        subscribed: false
      }
    }

    assert_redirected_to newsletter_subscriptions_path
    subscription.reload
    assert_equal "Updated", subscription.first_name
    assert_not subscription.subscribed
  end

  test "editor cannot access admin newsletter subscriptions" do
    sign_in users(:editor)
    get newsletter_subscriptions_path
    assert_redirected_to root_path
  end
end
