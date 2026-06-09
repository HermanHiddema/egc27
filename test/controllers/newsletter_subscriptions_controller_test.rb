require "test_helper"

class NewsletterSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "shows newsletter subscription page" do
    get newsletter_path

    assert_response :success
    assert_select "h1", text: "Newsletter"
    assert_select "form[action='#{newsletter_subscriptions_path}']"
  end

  test "creates a newsletter subscription" do
    assert_difference("NewsletterSubscription.count", 1) do
      post newsletter_subscriptions_path, params: {
        newsletter_subscription: {
          first_name: "Jane",
          last_name: "Doe",
          email: "jane@example.com"
        }
      }
    end

    assert_redirected_to newsletter_path
    assert_equal "Thanks for subscribing to the newsletter.", flash[:notice]
  end

  test "newsletter page includes turnstile widget when site key is configured" do
    previous = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
    ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = "1x00000000000000000000AA"
    get newsletter_path
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

  test "re-subscribes an existing unsubscribed email" do
    subscription = newsletter_subscriptions(:inactive)
    original_token = subscription.unsubscribe_token

    assert_no_difference("NewsletterSubscription.count") do
      post newsletter_subscriptions_path, params: {
        newsletter_subscription: {
          first_name: "Bobby",
          last_name: "Smith",
          email: "Bob@example.com"
        }
      }
    end

    assert_redirected_to newsletter_path
    subscription.reload
    assert_equal "Bobby", subscription.first_name
    assert_equal true, subscription.subscribed
    assert_nil subscription.unsubscribed_at
    assert_not_equal original_token, subscription.unsubscribe_token
  end

  test "renders newsletter page with errors for invalid newsletter subscription" do
    post newsletter_subscriptions_path, params: {
      newsletter_subscription: {
        first_name: "Jane",
        last_name: "",
        email: "invalid-email"
      }
    }

    assert_response :unprocessable_entity
    assert_select "h2", text: "There were errors with your submission:"
  end

  test "shows confirmation page for a valid unsubscribe token" do
    subscription = newsletter_subscriptions(:active)

    get unsubscribe_newsletter_path(subscription.unsubscribe_token)

    assert_response :success
    subscription.reload
    assert_equal true, subscription.subscribed
  end

  test "unsubscribes a valid token after confirmation" do
    subscription = newsletter_subscriptions(:active)

    delete destroy_unsubscribe_newsletter_path(subscription.unsubscribe_token)

    assert_redirected_to root_path
    assert_equal "You have been unsubscribed from the newsletter.", flash[:notice]
    subscription.reload
    assert_equal false, subscription.subscribed
    assert_not_nil subscription.unsubscribed_at
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
