require "test_helper"

class NewsletterMailerTest < ActionMailer::TestCase
  test "goodbye is sent to the subscriber with a resubscribe link" do
    subscription = newsletter_subscriptions(:active)
    resubscribe_token = "resubscribe-token"
    email = NewsletterMailer.goodbye(subscription, resubscribe_token: resubscribe_token)

    assert_equal [subscription.email], email.to
    assert_equal "EGC 2027 – You have been unsubscribed", email.subject

    body = email.body.decoded
    assert_match subscription.first_name, body
    resubscribe_url = Rails.application.routes.url_helpers.resubscribe_newsletter_url(
      resubscribe_token, host: "example.com", protocol: "https"
    )
    assert_match resubscribe_url, body
  end

  test "default footer icons are embedded in sent and test emails" do
    footer = ApplicationController.render(partial: "newsletters/default_footer")
    newsletter = Newsletter.create!(title: "Issue", subject: "News", content_html: footer, user: users(:editor))
    snapshot = newsletter.attributes.slice("title", "subject", "content_html")

    [NewsletterMailer.newsletter(newsletter, newsletter_subscriptions(:active)),
     NewsletterMailer.test_newsletter(newsletter.id, snapshot, "test@example.com")].each do |email|
      body = email.html_part.body.decoded
      assert_includes body, 'href="mailto:info@egc2027.nl"'
      ApplicationHelper::SOCIAL_MEDIA_LINKS.each_key do |platform|
        attachment = email.attachments["#{platform}.png"]
        assert attachment.inline?
        assert_includes body, attachment.url
        assert_equal File.binread(Rails.root.join("public/newsletter-social", "#{platform}.png")), attachment.decoded
      end
    end
  end

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
      token: subscription.subscription_token,
      host: "example.com",
      protocol: "https"
    )
    assert_match unsubscribe_url, body
  end

  test "welcome back includes the new unsubscribe link" do
    subscription = newsletter_subscriptions(:active)
    email = NewsletterMailer.welcome_back(subscription)

    assert_equal [subscription.email], email.to
    assert_equal "EGC 2027 – Welcome back to the newsletter", email.subject
    assert_includes email.body.decoded, "Welcome back"
    assert_includes email.body.decoded, subscription.subscription_token
  end

  test "welcome works for a subscriber without a name" do
    subscription = newsletter_subscriptions(:active)
    subscription.first_name = nil

    email = NewsletterMailer.welcome(subscription)

    assert_includes email.body.decoded, "Hello,"
    assert_includes email.body.decoded, subscription.subscription_token
  end

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
    assert_includes email.body.to_s, "/newsletter/unsubscribe/#{subscription.subscription_token}"
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

    snapshot = newsletter.attributes.slice("title", "subject", "content_html")
    email = NewsletterMailer.test_newsletter(newsletter.id, snapshot, "test@example.com")

    assert_equal ["test@example.com"], email.to
    assert_equal "[TEST] Draft subject", email.subject
    assert_includes email.body.to_s, "Preview content"
    assert_includes email.body.to_s, "This is a test email for a newsletter draft"
    assert_includes email.body.to_s, "https://example.com/newsletter/test_unsubscribe/"
    assert_includes email.body.to_s, "https://example.com/newsletter/test_preview/"
  end

  test "test newsletter email uses the saved snapshot when the draft changes before delivery" do
    newsletter = Newsletter.create!(
      title: "Saved draft",
      subject: "Saved subject",
      content_html: "<p>Saved body</p>",
      user: users(:editor)
    )
    snapshot = newsletter.attributes.slice("title", "subject", "content_html")
    newsletter.update!(title: "Later draft", subject: "Later subject", content_html: "<p>Later body</p>")

    email = NewsletterMailer.test_newsletter(newsletter.id, snapshot, "test@example.com")

    assert_equal "[TEST] Saved subject", email.subject
    assert_includes email.body.to_s, "<h1"
    assert_includes email.body.to_s, "Saved draft"
    assert_includes email.body.to_s, "Saved body"
    refute_includes email.body.to_s, "Later draft"
    refute_includes email.body.to_s, "Later body"
    assert_includes email.body.to_s, "https://example.com/newsletter/test_preview/"
  end
end
