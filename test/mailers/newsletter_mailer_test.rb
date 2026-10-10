require "test_helper"

class NewsletterMailerTest < ActionMailer::TestCase
  test "welcome greets the subscriber and includes an unsubscribe link" do
    subscription = newsletter_subscriptions(:active)
    email = NewsletterMailer.welcome(subscription)

    assert_equal [subscription.email], email.to
    assert_equal "EGC 2027 – Welcome to the newsletter", email.subject

    body = email.body.decoded
    assert_match subscription.first_name, body
    assert_match "Thank you for subscribing", body
    assert_match "If you did not subscribe to this list", body

    unsubscribe_url = Rails.application.routes.url_helpers.unsubscribe_newsletter_url(
      token: subscription.unsubscribe_token,
      host: "example.com"
    )
    assert_match unsubscribe_url, body
  end
end
