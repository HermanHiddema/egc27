require "test_helper"

class NewsletterSubscriptionTest < ActiveSupport::TestCase
  test "normalizes names and email" do
    subscription = NewsletterSubscription.create!(
      first_name: "  Jane ",
      last_name: " Doe  ",
      email: " Jane.Doe@Example.COM "
    )

    assert_equal "Jane", subscription.first_name
    assert_equal "Doe", subscription.last_name
    assert_equal "jane.doe@example.com", subscription.email
  end

  test "generates an unsubscribe token" do
    subscription = NewsletterSubscription.create!(
      first_name: "Jane",
      last_name: "Doe",
      email: "jane2@example.com"
    )

    assert subscription.unsubscribe_token.present?
  end

  test "unsubscribe marks the subscription as inactive" do
    subscription = newsletter_subscriptions(:active)

    subscription.unsubscribe!

    assert_equal false, subscription.subscribed
    assert_not_nil subscription.unsubscribed_at
  end
end
