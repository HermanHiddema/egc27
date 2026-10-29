require "test_helper"

class NewsletterDeliveryJobTest < ActiveJob::TestCase
  setup do
    @newsletter = Newsletter.create!(
      title: "A newsletter",
      subject: "A subject",
      content_html: "<p>Body</p>",
      user: users(:editor),
      sent_at: Time.current
    )
    @subscription = newsletter_subscriptions(:active)
    @delivery = NewsletterDelivery.create!(newsletter: @newsletter, newsletter_subscription: @subscription)
  end

  test "delivers the newsletter to a currently subscribed address" do
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      NewsletterDeliveryJob.perform_now(@delivery.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [@subscription.email], email.to
    assert_not_nil @delivery.reload.delivered_at
  end

  test "does not deliver the same newsletter to a subscriber twice" do
    NewsletterDeliveryJob.perform_now(@delivery.id)

    assert_no_difference "ActionMailer::Base.deliveries.size" do
      NewsletterDeliveryJob.perform_now(@delivery.id)
    end
  end

  test "releases the delivery claim when sending fails" do
    NewsletterMailer.singleton_class.define_method(:newsletter) { |*| raise Net::SMTPServerBusy, "busy" }

    begin
      assert_raises(Net::SMTPServerBusy) { NewsletterDeliveryJob.perform_now(@delivery.id) }
    ensure
      NewsletterMailer.singleton_class.remove_method(:newsletter)
    end

    assert_nil @delivery.reload.delivered_at
  end
end
