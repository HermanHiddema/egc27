require "test_helper"

class NewsletterDeliveryJobTest < ActiveJob::TestCase
  test "delivers the newsletter to a currently subscribed address" do
    newsletter = Newsletter.create!(
      title: "A newsletter",
      subject: "A subject",
      content_html: "<p>Body</p>",
      user: users(:editor),
      sent_at: Time.current
    )
    subscription = newsletter_subscriptions(:active)

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      NewsletterDeliveryJob.perform_now(newsletter.id, subscription.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [subscription.email], email.to
  end
end
