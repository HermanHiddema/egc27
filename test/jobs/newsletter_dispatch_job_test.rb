require "test_helper"

class NewsletterDispatchJobTest < ActiveJob::TestCase
  test "queues deliveries only for subscribers who are subscribed when dispatch runs" do
    newsletter = Newsletter.create!(
      title: "A newsletter",
      subject: "A subject",
      content_html: "<p>Body</p>",
      user: users(:editor),
      sent_at: Time.current
    )

    assert_enqueued_jobs 1, only: NewsletterDeliveryJob do
      NewsletterDispatchJob.perform_now(newsletter.id)
    end

    delivery = enqueued_jobs.find { |job| job[:job] == NewsletterDeliveryJob }
    assert_equal [newsletter.id, newsletter_subscriptions(:active).id], delivery[:args]
  end

  test "dispatch delivers to current subscribers" do
    newsletter = Newsletter.create!(
      title: "A newsletter",
      subject: "A subject",
      content_html: "<p>Body</p>",
      user: users(:editor),
      sent_at: Time.current
    )

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      perform_enqueued_jobs do
        NewsletterDispatchJob.perform_later(newsletter.id)
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [newsletter_subscriptions(:active).email], email.to
  end
end
