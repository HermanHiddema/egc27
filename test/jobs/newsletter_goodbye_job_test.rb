require "test_helper"

class NewsletterGoodbyeJobTest < ActiveJob::TestCase
  test "delivers the goodbye email using the token captured when unsubscribing" do
    subscription = newsletter_subscriptions(:active)
    subscription.unsubscribe!
    resubscribe_token = subscription.subscription_token
    subscription.resubscribe!

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      NewsletterGoodbyeJob.perform_now(subscription.id, resubscribe_token)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [subscription.email], email.to
    assert_includes email.body.decoded, resubscribe_token
  end
end
