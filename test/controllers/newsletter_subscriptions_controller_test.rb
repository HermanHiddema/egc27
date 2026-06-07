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

  test "re-subscribes an existing unsubscribed email" do
    subscription = newsletter_subscriptions(:inactive)

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
  end

  test "renders home with errors for invalid newsletter subscription" do
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

  test "unsubscribes a valid token" do
    subscription = newsletter_subscriptions(:active)

    get unsubscribe_newsletter_path(subscription.unsubscribe_token)

    assert_redirected_to root_path
    assert_equal "You have been unsubscribed from the newsletter.", flash[:notice]
    subscription.reload
    assert_equal false, subscription.subscribed
    assert_not_nil subscription.unsubscribed_at
  end

  test "rejects invalid unsubscribe token" do
    get unsubscribe_newsletter_path("missing-token")

    assert_redirected_to root_path
    assert_equal "Invalid unsubscribe link.", flash[:alert]
  end
end
