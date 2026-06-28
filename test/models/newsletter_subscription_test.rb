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

  test "subscribe_user adds a confirmed user's participant to the list" do
    user = User.create!(email: "Jane.New@Example.com", skip_password_validation: true)
    user.update_column(:confirmed_at, Time.current)
    Participant.create!(
      first_name: "Jane",
      last_name: "Doe",
      email: user.email,
      age_group: "18-49",
      country: "NL",
      gender: "female",
      image_use_consent: true,
      user: user
    )

    assert_difference("NewsletterSubscription.count", 1) do
      NewsletterSubscription.subscribe_user(user)
    end

    subscription = NewsletterSubscription.find_by(email: "jane.new@example.com")
    assert_not_nil subscription
    assert_equal "Jane", subscription.first_name
    assert_equal "Doe", subscription.last_name
    assert subscription.subscribed
  end

  test "subscribe_user does not change an existing subscription" do
    existing = newsletter_subscriptions(:inactive)
    user = User.create!(email: existing.email.upcase, skip_password_validation: true)
    user.update_column(:confirmed_at, Time.current)
    Participant.create!(
      first_name: "Changed",
      last_name: "Name",
      email: user.email,
      age_group: "18-49",
      country: "NL",
      gender: "male",
      image_use_consent: true,
      user: user
    )

    assert_no_difference("NewsletterSubscription.count") do
      NewsletterSubscription.subscribe_user(user)
    end

    existing.reload
    assert_equal "Bob", existing.first_name
    assert_equal false, existing.subscribed
  end

  test "subscribe_user ignores users without a participant" do
    user = User.create!(email: "no_participant@example.com", skip_password_validation: true)

    assert_no_difference("NewsletterSubscription.count") do
      NewsletterSubscription.subscribe_user(user)
    end
  end

  test "subscribe_user ignores a nil user" do
    assert_no_difference("NewsletterSubscription.count") do
      NewsletterSubscription.subscribe_user(nil)
    end
  end

  test "update_email moves a subscription to the new address" do
    subscription = NewsletterSubscription.create!(
      first_name: "Jane",
      last_name: "Doe",
      email: "old.address@example.com"
    )

    NewsletterSubscription.update_email("Old.Address@example.com", "New.Address@example.com")

    assert_equal "new.address@example.com", subscription.reload.email
  end

  test "update_email is a no-op when no subscription matches the old address" do
    assert_nothing_raised do
      NewsletterSubscription.update_email("missing@example.com", "new@example.com")
    end

    assert_nil NewsletterSubscription.find_by(email: "new@example.com")
  end

  test "update_email ignores blank or unchanged addresses" do
    subscription = NewsletterSubscription.create!(
      first_name: "Jane",
      last_name: "Doe",
      email: "stable@example.com"
    )

    NewsletterSubscription.update_email("stable@example.com", "")
    NewsletterSubscription.update_email("", "new@example.com")
    NewsletterSubscription.update_email("stable@example.com", "stable@example.com")

    assert_equal "stable@example.com", subscription.reload.email
  end

  test "update_email removes the old subscription when the new address already has one" do
    old_subscription = NewsletterSubscription.create!(
      first_name: "Jane",
      last_name: "Doe",
      email: "old@example.com"
    )
    new_subscription = NewsletterSubscription.create!(
      first_name: "Jane",
      last_name: "Doe",
      email: "new@example.com",
      subscribed: false
    )

    assert_difference("NewsletterSubscription.count", -1) do
      NewsletterSubscription.update_email("old@example.com", "new@example.com")
    end

    assert_nil NewsletterSubscription.find_by(id: old_subscription.id)
    new_subscription.reload
    assert_equal "new@example.com", new_subscription.email
    assert_equal false, new_subscription.subscribed
  end

  test "update_email keeps the old subscription when the new address is invalid" do
    subscription = NewsletterSubscription.create!(
      first_name: "Jane",
      last_name: "Doe",
      email: "old@example.com"
    )

    assert_nothing_raised do
      NewsletterSubscription.update_email("old@example.com", "invalid-email")
    end

    assert_equal "old@example.com", subscription.reload.email
  end
end
