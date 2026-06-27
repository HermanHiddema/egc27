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

  test "unsubscribe preserves existing unsubscribed_at" do
    subscription = newsletter_subscriptions(:inactive)
    unsubscribed_at = subscription.unsubscribed_at

    subscription.unsubscribe!

    assert_equal unsubscribed_at, subscription.reload.unsubscribed_at
  end

  test "subscribe_from_participant adds a new participant to the list" do
    participant = Participant.new(first_name: "Jane", last_name: "Doe", email: "Jane.New@Example.com")

    assert_difference("NewsletterSubscription.count", 1) do
      NewsletterSubscription.subscribe_from_participant(participant)
    end

    subscription = NewsletterSubscription.find_by(email: "jane.new@example.com")
    assert_not_nil subscription
    assert_equal "Jane", subscription.first_name
    assert_equal "Doe", subscription.last_name
    assert subscription.subscribed
  end

  test "subscribe_from_participant does not change an existing subscription" do
    existing = newsletter_subscriptions(:inactive)
    participant = Participant.new(first_name: "Changed", last_name: "Name", email: existing.email.upcase)

    assert_no_difference("NewsletterSubscription.count") do
      NewsletterSubscription.subscribe_from_participant(participant)
    end

    existing.reload
    assert_equal "Bob", existing.first_name
    assert_equal false, existing.subscribed
  end

  test "subscribe_from_participant ignores participants without an email" do
    participant = Participant.new(first_name: "Jane", last_name: "Doe", email: "")

    assert_no_difference("NewsletterSubscription.count") do
      NewsletterSubscription.subscribe_from_participant(participant)
    end
  end
end
