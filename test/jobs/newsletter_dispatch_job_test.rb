require "test_helper"

class NewsletterDispatchJobTest < ActiveJob::TestCase
  setup do
    @newsletter = Newsletter.create!(
      title: "A newsletter",
      subject: "A subject",
      content_html: "<p>Body</p>",
      user: users(:editor),
      sent_at: Time.current
    )
  end

  test "queues deliveries only for subscribers who are subscribed when dispatch runs" do
    assert_enqueued_jobs 1, only: NewsletterDeliveryJob do
      NewsletterDispatchJob.perform_now(@newsletter.id)
    end

    delivery = NewsletterDelivery.find_by!(newsletter: @newsletter)
    assert_equal newsletter_subscriptions(:active), delivery.newsletter_subscription
    job = enqueued_jobs.find { |enqueued| enqueued[:job] == NewsletterDeliveryJob }
    assert_equal [delivery.id], job[:args]
  end

  test "dispatch delivers to current subscribers" do
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      perform_enqueued_jobs do
        NewsletterDispatchJob.perform_later(@newsletter.id)
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [newsletter_subscriptions(:active).email], email.to
  end

  test "re-running dispatch does not resend to already delivered subscribers" do
    perform_enqueued_jobs do
      NewsletterDispatchJob.perform_later(@newsletter.id)
    end

    assert_no_difference ["ActionMailer::Base.deliveries.size", "NewsletterDelivery.count"] do
      perform_enqueued_jobs do
        NewsletterDispatchJob.perform_later(@newsletter.id)
      end
    end
  end

  test "re-running a partial dispatch resumes pending deliveries" do
    NewsletterDispatchJob.perform_now(@newsletter.id)
    clear_enqueued_jobs

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      perform_enqueued_jobs do
        NewsletterDispatchJob.perform_later(@newsletter.id)
      end
    end
    assert_equal 1, NewsletterDelivery.where(newsletter: @newsletter).count
  end
end
