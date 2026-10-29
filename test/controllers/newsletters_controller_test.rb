require "test_helper"

class NewslettersControllerTest < ActionDispatch::IntegrationTest
  test "editor form exposes working preview save and send actions without a required hidden textarea" do
    sign_in users(:editor)

    get new_newsletter_path

    assert_response :success
    assert_select 'textarea[name="newsletter[content_html]"][required]', count: 0
    assert_select 'textarea[data-tinymce-plugins-value="lists link image autoresize"]'
    assert_select 'button[name="intent"][value="preview"]', text: "Preview"
    assert_select 'button[name="intent"][value="save"]', text: "Save draft"
    assert_select 'button[name="intent"][value="send"]', text: "Send"
    assert_select 'button[name="intent"][value="test_send"]', text: "Send test"
    assert_select 'button[type="button"]', text: "Send test email"
    assert_select 'form[data-controller~="newsletter-send"][data-controller~="newsletter-test-send"][data-newsletter-send-recipient-count-value="1"]'
    assert_select "dialog[data-newsletter-test-send-target='dialog']"
  end

  test "editor can create a newsletter and preview its saved content" do
    sign_in users(:editor)

    assert_difference "Newsletter.count", 1 do
      post newsletters_path, params: {
        newsletter: { title: "Spring update", subject: "News from EGC", content_html: "<p>Welcome</p>" },
        intent: "preview"
      }
    end

    newsletter = Newsletter.order(:id).last
    assert_redirected_to preview_newsletter_path(newsletter)

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Welcome"
    assert_select ".newsletter-document"
  end

  test "save draft returns to the editor with the draft stored" do
    sign_in users(:editor)

    post newsletters_path, params: {
      newsletter: { title: "Saved draft", subject: "Draft subject", content_html: "<p>Draft content</p>" },
      intent: "save"
    }

    newsletter = Newsletter.order(:id).last
    assert_redirected_to edit_newsletter_path(newsletter)
    assert_equal "Saved draft", newsletter.title
    assert_equal "Draft subject", newsletter.subject
    assert_equal "<p>Draft content</p>", newsletter.content_html
  end

  test "test send saves the draft and sends one separate email to each entered address" do
    sign_in users(:editor)

    assert_difference "Newsletter.count", 1 do
      assert_enqueued_emails 2 do
        post newsletters_path, params: {
          newsletter: { title: "Test issue", subject: "Test subject", content_html: "<p>Test body</p>" },
          intent: "test_send",
          test_recipients: "first@example.com, SECOND@example.com"
        }
      end
    end

    newsletter = Newsletter.order(:id).last
    assert_redirected_to edit_newsletter_path(newsletter)
    assert_equal "Test issue", newsletter.title
    assert_not newsletter.sent?
    assert_empty newsletter.newsletter_deliveries
    assert_includes flash[:notice], "Test email queued for 2 addresses"
  end

  test "test send rejects invalid recipient addresses without saving or enqueueing emails" do
    sign_in users(:editor)

    assert_no_difference "Newsletter.count" do
      assert_no_enqueued_emails do
        post newsletters_path, params: {
          newsletter: { title: "Test issue", subject: "Test subject", content_html: "<p>Test body</p>" },
          intent: "test_send",
          test_recipients: "valid@example.com, not-an-email"
        }
      end
    end

    assert_response :unprocessable_entity
    assert_select 'form[data-newsletter-test-send-open-value="true"]'
    assert_select 'textarea[name="test_recipients"][aria-invalid="true"][aria-describedby~="newsletter-test-recipients-error"]'
    assert_select "#newsletter-test-recipients-error[role='alert']", text: /Enter valid email addresses/
  end

  test "test send updates the current draft without publishing or creating subscriber deliveries" do
    sign_in users(:editor)
    newsletter = create_newsletter

    assert_enqueued_emails 1 do
      patch newsletter_path(newsletter), params: {
        newsletter: { title: "Updated test draft", subject: "Updated test subject", content_html: "<p>Updated test body</p>" },
        intent: "test_send",
        test_recipients: "editor@example.com"
      }
    end

    assert_redirected_to edit_newsletter_path(newsletter)
    newsletter.reload
    assert_equal "Updated test draft", newsletter.title
    assert_equal "Updated test subject", newsletter.subject
    assert_equal "<p>Updated test body</p>", newsletter.content_html
    assert_not newsletter.sent?
    assert_empty newsletter.newsletter_deliveries

    newsletter.update!(title: "Changed after queue", subject: "Changed after queue", content_html: "<p>Changed after queue</p>")
    perform_enqueued_jobs

    email = ActionMailer::Base.deliveries.last
    assert_equal "[TEST] Updated test subject", email.subject
    assert_includes email.body.to_s, "Updated test draft"
    assert_includes email.body.to_s, "Updated test body"
    refute_includes email.body.to_s, "Changed after queue"
  end

  test "test preview link displays an unpublished newsletter without editor controls" do
    newsletter = create_newsletter
    token = NewsletterTestEmailLink.preview_token(newsletter)

    get test_newsletter_preview_path(token: token)

    assert_response :success
    assert_includes response.body, "Newsletter body"
    assert_includes response.body, "Test preview"
    assert_select 'button[name="intent"]', count: 0
    assert_select 'a[href*="/newsletter/preview"]', count: 0
  end

  test "test unsubscribe link shows confirmation without changing a matching subscription" do
    subscription = newsletter_subscriptions(:active)
    token = NewsletterTestEmailLink.unsubscribe_token(subscription.email)

    get test_newsletter_unsubscribe_path(token: token)

    assert_response :success
    assert_select "h1", text: "Confirm unsubscribe"
    assert_select "form[action=?]", destroy_test_newsletter_unsubscribe_path(token)
    assert subscription.reload.subscribed?
  end

  test "test unsubscribe link unsubscribes a matching address after confirmation" do
    subscription = newsletter_subscriptions(:active)
    token = NewsletterTestEmailLink.unsubscribe_token(subscription.email)

    delete destroy_test_newsletter_unsubscribe_path(token: token)

    assert_redirected_to newsletter_signup_path
    assert_not subscription.reload.subscribed?
  end

  test "test unsubscribe link confirms test-only recipients without changing subscriptions" do
    token = NewsletterTestEmailLink.unsubscribe_token("not-subscribed@example.com")

    assert_no_difference "NewsletterSubscription.count" do
      get test_newsletter_unsubscribe_path(token: token)
    end

    assert_response :success
    assert_includes response.body, "This test recipient is not subscribed. No subscription was changed."
  end

  test "editor can review subscriber count and cancel back to the draft" do
    sign_in users(:editor)
    newsletter = create_newsletter

    get confirm_send_newsletter_path(newsletter)

    assert_response :success
    assert_includes response.body, "Sending newsletter to 1 addressee"
    assert_select "form[action=?]", send_newsletter_path(newsletter)
    assert_select "a[href=?]", edit_newsletter_path(newsletter), text: "Cancel"
  end

  test "preview includes the confirmed send button" do
    sign_in users(:editor)
    newsletter = create_newsletter

    get preview_newsletter_path(newsletter)

    assert_response :success
    assert_select "form[action=?][data-controller='newsletter-send']", send_newsletter_path(newsletter)
    assert_select "button[name='intent'][value='send']", text: "Send"
  end

  test "review send saves the current editor state so cancel returns to it" do
    sign_in users(:editor)

    post newsletters_path, params: {
      newsletter: { title: "Latest title", subject: "Latest subject", content_html: "<p>Latest content</p>" },
      intent: "send",
      recipient_count: 1
    }
    newsletter = Newsletter.order(:id).last

    assert_redirected_to confirm_send_newsletter_path(newsletter)
    get edit_newsletter_path(newsletter)

    assert_response :success
    assert_equal "Latest title", newsletter.reload.title
    assert_equal "Latest subject", newsletter.subject
    assert_equal "<p>Latest content</p>", newsletter.content_html
  end

  test "sending from the editor queues delivery after the confirmation popup has been accepted" do
    sign_in users(:editor)

    assert_enqueued_with(job: NewsletterDispatchJob) do
      post newsletters_path, params: {
        newsletter: { title: "Send now", subject: "Hello", content_html: "<p>Body</p>" },
        intent: "send",
        confirmed_send: "1",
        recipient_count: 1
      }
    end

    newsletter = Newsletter.order(:id).last
    assert newsletter.sent?
    assert_redirected_to newsletter_path(newsletter)
  end

  test "subscriber count changes require a new confirmation" do
    sign_in users(:editor)
    newsletter = create_newsletter

    assert_no_enqueued_jobs only: NewsletterDispatchJob do
      post send_newsletter_path(newsletter), params: { recipient_count: 4, confirmed_send: "1" }
    end

    assert_redirected_to confirm_send_newsletter_path(newsletter)
    follow_redirect!
    assert_response :success
    assert_includes response.body, "subscriber count changed"
    assert_includes response.body, "Sending newsletter to 1 addressee"
    assert_nil newsletter.reload.sent_at
  end

  test "confirmed send queues delivery and publishes the newsletter" do
    sign_in users(:editor)
    newsletter = create_newsletter

    assert_enqueued_with(job: NewsletterDispatchJob, args: [newsletter.id]) do
      post send_newsletter_path(newsletter), params: { recipient_count: 1, confirmed_send: "1" }
    end

    assert newsletter.reload.sent?
    assert_redirected_to newsletter_path(newsletter)
  end

  test "sent newsletters cannot be updated" do
    sign_in users(:editor)
    newsletter = create_newsletter(sent_at: 1.hour.ago)

    patch newsletter_path(newsletter), params: { newsletter: { title: "Changed", subject: "Changed", content_html: "<p>Changed</p>" } }

    assert_redirected_to newsletter_signup_path
    assert_not_equal "Changed", newsletter.reload.title
  end

  test "newsletter overview lists sent newsletters and hides drafts" do
    sent = create_newsletter(sent_at: 1.hour.ago)
    draft = create_newsletter(title: "Private draft")

    get newsletter_signup_path

    assert_response :success
    assert_includes response.body, sent.title
    refute_includes response.body, draft.title
    assert_select "a[href=?] article", newsletter_path(sent), count: 1

    get newsletter_path(sent)
    assert_response :success
    assert_includes response.body, sent.content_html
    assert_select ".newsletter-document"

    get newsletter_path(draft)
    assert_response :not_found
  end

  test "the former plural overview route is removed" do
    get "/newsletters"

    assert_response :not_found
  end

  test "editors see drafts above sent newsletters and both top actions" do
    sign_in users(:editor)
    sent = create_newsletter(title: "Sent issue", sent_at: 1.hour.ago)
    draft = create_newsletter(title: "Draft issue")

    get newsletter_signup_path

    assert_response :success
    assert_select "h2", text: "Drafts"
    assert_select "a[href=?]", new_newsletter_path, text: "Create newsletter"
    assert_select "button", text: "Subscribe"
    assert_operator response.body.index(draft.title), :<, response.body.index(sent.title)
  end

  test "regular users cannot create or edit newsletters" do
    sign_in users(:one)
    get new_newsletter_path
    assert_redirected_to root_path

    newsletter = create_newsletter
    patch newsletter_path(newsletter), params: { newsletter: { title: "Changed" } }
    assert_redirected_to root_path
    assert_equal "A newsletter", newsletter.reload.title
  end

  private

  def create_newsletter(attributes = {})
    Newsletter.create!({
      title: "A newsletter",
      subject: "A subject",
      content_html: "<p>Newsletter body</p>",
      user: users(:editor)
    }.merge(attributes))
  end
end
