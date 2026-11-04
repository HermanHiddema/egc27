require "test_helper"

class NewsletterWelcomeJobTest < ActiveJob::TestCase
  test "delivers the welcome email to an active subscription" do
    subscription = newsletter_subscriptions(:active)

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      NewsletterWelcomeJob.perform_now(subscription.id)
    end
  end

  test "does not deliver the welcome email after the subscription is deactivated" do
    subscription = newsletter_subscriptions(:active)
    subscription.unsubscribe!

    assert_no_difference "ActionMailer::Base.deliveries.size" do
      NewsletterWelcomeJob.perform_now(subscription.id)
    end
  end
end
