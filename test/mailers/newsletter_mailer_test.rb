require "test_helper"

class NewsletterMailerTest < ActionMailer::TestCase
  test "newsletter email is addressed to one subscriber and includes archive and unsubscribe links" do
    newsletter = Newsletter.create!(
      title: "Spring update",
      subject: "News from EGC",
      content_html: '<p>Welcome</p><table class="newsletter-layout-locked" width="100%"><tr><td width="50%"><img src="/rails/blobs/redirect/abc/layout.png" style="display:block; width:100%; max-width:100%; height:auto;"></td><td width="50%"><p>More news</p></td></tr></table><script>alert(1)</script><img src="/rails/blobs/redirect/abc/photo.png" onerror="alert(1)"><img src="https://localhost:3000/rails/blobs/redirect/abc/uploaded.png"><img src="//cdn.example.org/external.png">',
      user: users(:editor),
      sent_at: Time.current
    )
    subscription = newsletter_subscriptions(:active)

    email = NewsletterMailer.newsletter(newsletter, subscription)

    assert_equal [subscription.email], email.to
    assert_equal newsletter.subject, email.subject
    assert_includes email.body.to_s, "Welcome"
    assert_includes email.body.to_s, "<p>Welcome</p>"
    assert_includes email.body.to_s, 'width="1200"'
    assert_includes email.body.to_s, "@media only screen and (max-width: 640px)"
    assert_includes email.body.to_s, "table.newsletter-layout-locked td"
    assert_includes email.body.to_s, "table.newsletter-layout-locked tr"
    assert_includes email.body.to_s, "table.newsletter-layout-locked figure.image.img-align-center"
    assert_includes email.body.to_s, 'class="newsletter-layout-locked"'
    assert_includes email.body.to_s, "https://example.com/rails/blobs/redirect/abc/layout.png"
    assert_includes email.body.to_s, "https://example.com/rails/blobs/redirect/abc/photo.png"
    assert_includes email.body.to_s, "https://example.com/rails/blobs/redirect/abc/uploaded.png"
    assert_includes email.body.to_s, 'src="https://cdn.example.org/external.png"'
    refute_includes email.body.to_s, "example.com//cdn.example.org"
    assert_equal 1, email.body.to_s.scan(/<html/i).size
    assert_equal 1, email.body.to_s.scan(/<head>/i).size
    assert_includes email.body.to_s, "/newsletter/unsubscribe/#{subscription.unsubscribe_token}"
    assert_includes email.body.to_s, "/newsletter/#{newsletter.id}"
    refute_includes email.body.to_s, "<script"
    refute_includes email.body.to_s, "onerror"
  end

  test "test newsletter email is addressed only to its test recipient and has no subscriber links" do
    newsletter = Newsletter.create!(
      title: "Draft issue",
      subject: "Draft subject",
      content_html: "<p>Preview content</p>",
      user: users(:editor)
    )

    email = NewsletterMailer.test_newsletter(newsletter, "test@example.com")

    assert_equal ["test@example.com"], email.to
    assert_equal "[TEST] Draft subject", email.subject
    assert_includes email.body.to_s, "Preview content"
    assert_includes email.body.to_s, "This is a test email for a newsletter draft"
    assert_includes email.body.to_s, "http://example.com/newsletter/test_unsubscribe/"
    assert_includes email.body.to_s, "http://example.com/newsletter/test_preview/"
  end
end
