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
    assert_select 'form[data-controller="newsletter-send"][data-newsletter-send-recipient-count-value="1"]'
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
