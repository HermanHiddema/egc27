require "test_helper"

class NewsletterSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "shows the newsletter overview and subscribe modal" do
    get newsletter_signup_path

    assert_response :success
    assert_select "h1", text: "Newsletter"
    assert_select "form[action='#{newsletter_subscriptions_path}']"
    assert_select "dialog[data-newsletter-subscribe-target='dialog']"
    assert_select "button", text: "Subscribe"
    assert_select "button", text: "Cancel"
  end

  test "creates a newsletter subscription" do
    assert_difference("NewsletterSubscription.count", 1) do
      post newsletter_subscriptions_path, params: {
        newsletter_subscription: {
          email: "jane@example.com"
        }
      }
    end

    assert_redirected_to newsletter_signup_path
    assert_equal "Thanks for subscribing to the newsletter.", flash[:notice]

    subscription = NewsletterSubscription.find_by(email: "jane@example.com")
    assert_not_nil subscription
    assert subscription.first_name.blank?
    assert subscription.last_name.blank?
  end

  test "sends a welcome email when a subscription is created" do
    assert_enqueued_with job: NewsletterWelcomeJob, args: ->(args) {
      args == [NewsletterSubscription.find_by(email: "jane@example.com")&.id]
    } do
      post newsletter_subscriptions_path, params: {
        newsletter_subscription: {
          first_name: "Jane",
          last_name: "Doe",
          email: "jane@example.com"
        }
      }
    end
  end

  test "newsletter page includes turnstile widget when site key is configured" do
    previous = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
    ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = "1x00000000000000000000AA"
    get newsletter_signup_path
    assert_select "div.cf-turnstile"
  ensure
    if previous.nil?
      ENV.delete("CLOUDFLARE_TURNSTILE_SITE_KEY")
    else
      ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = previous
    end
  end

  test "requires turnstile verification to create newsletter subscription when configured" do
    previous_secret = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
    previous_site = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
    ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = "test-secret-key"
    ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = "1x00000000000000000000AA"
    post newsletter_subscriptions_path, params: {
      newsletter_subscription: {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com"
      }
    }

    assert_response :unprocessable_entity
    assert_equal "CAPTCHA verification failed. Please try again.", flash[:alert]
  ensure
    if previous_secret.nil?
      ENV.delete("CLOUDFLARE_TURNSTILE_SECRET_KEY")
    else
      ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = previous_secret
    end
    if previous_site.nil?
      ENV.delete("CLOUDFLARE_TURNSTILE_SITE_KEY")
    else
      ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = previous_site
    end
  end

  test "does not resubscribe an existing unsubscribed email on create" do
    subscription = newsletter_subscriptions(:inactive)

    assert_no_enqueued_jobs only: NewsletterWelcomeJob do
      assert_no_difference("NewsletterSubscription.count") do
        post newsletter_subscriptions_path, params: {
          newsletter_subscription: {
            email: "Bob@example.com"
          }
        }
      end
    end

    assert_response :unprocessable_entity
    subscription.reload
    assert_equal "Bob", subscription.first_name
    assert_equal false, subscription.subscribed
    assert_not_nil subscription.unsubscribed_at
  end

  test "does not resubscribe an existing subscribed email on create" do
    assert_no_difference("NewsletterSubscription.count") do
      post newsletter_subscriptions_path, params: {
        newsletter_subscription: {
          first_name: "Alice",
          last_name: "Jones",
          email: "Alice@example.com"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "renders newsletter page with an email-taken error after a concurrent insert" do
    subscription = newsletter_subscriptions(:inactive)
    attempted_subscription = NewsletterSubscription.new(email: subscription.email)
    original_new = NewsletterSubscription.method(:new)
    original_save = attempted_subscription.method(:save)
    NewsletterSubscription.define_singleton_method(:new) { |*| attempted_subscription }
    attempted_subscription.define_singleton_method(:save) { raise ActiveRecord::RecordNotUnique }

    post newsletter_subscriptions_path, params: {
      newsletter_subscription: {
        email: subscription.email
      }
    }
    assert_response :unprocessable_entity
    assert_includes attempted_subscription.errors.full_messages, "Email has already been taken"
    assert_not subscription.reload.subscribed?
    assert_equal "Bob", subscription.first_name
  ensure
    if original_new
      NewsletterSubscription.define_singleton_method(:new, original_new)
      attempted_subscription.define_singleton_method(:save, original_save)
    end
  end

  test "rejects an active subscription without another welcome email" do
    subscription = newsletter_subscriptions(:active)

    assert_no_enqueued_jobs only: NewsletterWelcomeJob do
      post newsletter_subscriptions_path, params: {
        newsletter_subscription: {
          email: subscription.email
        }
      }
    end

    assert_response :unprocessable_entity
    assert subscription.reload.subscribed?
  end

  test "renders newsletter page with errors for invalid newsletter subscription" do
    post newsletter_subscriptions_path, params: {
      newsletter_subscription: {
        email: "invalid-email"
      }
    }

    assert_response :unprocessable_entity
    assert_select "h3", text: "There were errors with your submission:"
    assert_select 'div[data-newsletter-subscribe-auto-open-value="true"]'
  end

  test "shows confirmation page for a valid unsubscribe token" do
    subscription = newsletter_subscriptions(:active)

    get unsubscribe_newsletter_path(subscription.subscription_token)

    assert_response :success
    subscription.reload
    assert_equal true, subscription.subscribed
  end

  test "rejects an unsubscribe link after the subscription has been unsubscribed" do
    subscription = newsletter_subscriptions(:inactive)

    get unsubscribe_newsletter_path(subscription.subscription_token)

    assert_redirected_to root_path
    assert_equal "Invalid unsubscribe link.", flash[:alert]
  end

  test "unsubscribes a valid token after confirmation" do
    subscription = newsletter_subscriptions(:active)
    used_token = subscription.subscription_token

    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      perform_enqueued_jobs do
        delete destroy_unsubscribe_newsletter_path(used_token)
      end
    end

    assert_redirected_to root_path
    assert_equal "You have been unsubscribed from the newsletter.", flash[:notice]
    subscription.reload
    assert_equal false, subscription.subscribed
    assert_not_nil subscription.unsubscribed_at
    assert subscription.subscription_token.present?
    assert_not_equal used_token, subscription.subscription_token

    goodbye = ActionMailer::Base.deliveries.last
    assert_equal [subscription.email], goodbye.to
    assert_match resubscribe_newsletter_path(subscription.subscription_token), goodbye.body.decoded
  end

  test "does not send another goodbye email when already unsubscribed" do
    subscription = newsletter_subscriptions(:inactive)
    used_token = subscription.subscription_token

    assert_no_difference("ActionMailer::Base.deliveries.size") do
      delete destroy_unsubscribe_newsletter_path(used_token)
    end

    assert_redirected_to root_path
    assert_equal "Invalid unsubscribe link.", flash[:alert]
  end

  test "shows confirmation for a valid resubscribe token without changing the subscription" do
    subscription = newsletter_subscriptions(:inactive)
    used_token = subscription.subscription_token

    get resubscribe_newsletter_path(used_token)

    assert_response :success
    assert_select "h1", text: "Confirm resubscribe"
    assert_select "form[action=?][method=post]", confirm_resubscribe_newsletter_path(used_token)
    assert_not subscription.reload.subscribed?
  end

  test "resubscribes only after explicit confirmation" do
    subscription = newsletter_subscriptions(:inactive)
    used_token = subscription.subscription_token

    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      post confirm_resubscribe_newsletter_path(used_token)
    end

    assert_redirected_to newsletter_signup_path
    assert_equal "You have been resubscribed to the newsletter.", flash[:notice]
    subscription.reload
    assert_equal true, subscription.subscribed
    assert_nil subscription.unsubscribed_at
    assert subscription.subscription_token.present?
    assert_not_equal used_token, subscription.subscription_token
    assert_equal "EGC 2027 – Welcome back to the newsletter", ActionMailer::Base.deliveries.last.subject
  end

  test "rejects reuse of a resubscribe token" do
    subscription = newsletter_subscriptions(:inactive)
    used_token = subscription.subscription_token

    post confirm_resubscribe_newsletter_path(used_token)
    post confirm_resubscribe_newsletter_path(used_token)

    assert_redirected_to root_path
    assert_equal "Invalid resubscribe link.", flash[:alert]
  end

  test "rejects invalid resubscribe token" do
    post confirm_resubscribe_newsletter_path("missing-token")

    assert_redirected_to root_path
    assert_equal "Invalid resubscribe link.", flash[:alert]
  end

  test "rejects an invalid resubscribe token in the confirmation page" do
    get resubscribe_newsletter_path("missing-token")

    assert_redirected_to root_path
    assert_equal "Invalid resubscribe link.", flash[:alert]
  end

  test "rejects invalid unsubscribe token in confirmation" do
    get unsubscribe_newsletter_path("missing-token")

    assert_redirected_to root_path
    assert_equal "Invalid unsubscribe link.", flash[:alert]
  end

  test "rejects invalid unsubscribe token on unsubscribe" do
    delete destroy_unsubscribe_newsletter_path("missing-token")

    assert_redirected_to root_path
    assert_equal "Invalid unsubscribe link.", flash[:alert]
  end
end
