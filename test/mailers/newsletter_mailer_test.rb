require "test_helper"

class NewsletterMailerTest < ActionMailer::TestCase
  test "newsletter email is addressed to one subscriber and includes archive and unsubscribe links" do
    newsletter = Newsletter.create!(
      title: "Spring update",
      subject: "News from EGC",
      content_html: '<p>Welcome</p><script>alert(1)</script><img src="/rails/blobs/redirect/abc/photo.png" onerror="alert(1)">',
      user: users(:editor),
      sent_at: Time.current
    )
    subscription = newsletter_subscriptions(:active)

    email = NewsletterMailer.newsletter(newsletter, subscription)

    assert_equal [subscription.email], email.to
    assert_equal newsletter.subject, email.subject
    assert_includes email.body.to_s, "Welcome"
    assert_includes email.body.to_s, "<p>Welcome</p>"
    assert_includes email.body.to_s, "https://example.com/rails/blobs/redirect/abc/photo.png"
    assert_includes email.body.to_s, "/newsletter/unsubscribe/#{subscription.unsubscribe_token}"
    assert_includes email.body.to_s, "/newsletter/#{newsletter.id}"
    refute_includes email.body.to_s, "<script"
    refute_includes email.body.to_s, "onerror"
  end
end
