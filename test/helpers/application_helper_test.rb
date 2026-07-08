require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "field_error renders an inline message for an attribute with errors" do
    subscription = NewsletterSubscription.new
    subscription.valid?

    html = field_error(subscription, :email)

    assert_not_nil html
    assert_includes html, "text-red-600"
    assert_match(/blank/i, html)
  end

  test "field_error returns nil when the attribute has no errors" do
    subscription = NewsletterSubscription.new
    subscription.valid?

    assert_nil field_error(subscription, :subscribed)
  end

  test "field_error accepts a form builder and reads its object" do
    subscription = NewsletterSubscription.new
    subscription.valid?
    builder = ActionView::Helpers::FormBuilder.new(:newsletter_subscription, subscription, self, {})

    html = field_error(builder, :email)

    assert_not_nil html
    assert_includes html, "text-red-600"
  end
end
