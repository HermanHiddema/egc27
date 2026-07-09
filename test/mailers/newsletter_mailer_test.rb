require "test_helper"

class NewsletterMailerTest < ActionMailer::TestCase
  test "goodbye is sent to the subscriber with a resubscribe link" do
    subscription = newsletter_subscriptions(:active)
    email = NewsletterMailer.goodbye(subscription)

    assert_equal [subscription.email], email.to
    assert_equal "EGC 2027 – You have been unsubscribed", email.subject

    body = email.body.decoded
    assert_match subscription.first_name, body
    resubscribe_url = Rails.application.routes.url_helpers.resubscribe_newsletter_url(
      subscription.unsubscribe_token, host: "example.com"
    )
    assert_match resubscribe_url, body
  end
end
