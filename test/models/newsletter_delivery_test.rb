require "test_helper"

# == Schema Information
#
# Table name: newsletter_deliveries
#
#  id                         :bigint           not null, primary key
#  delivered_at               :datetime
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  newsletter_id              :bigint           not null
#  newsletter_subscription_id :bigint           not null
#
# Indexes
#
#  index_newsletter_deliveries_on_newsletter_and_subscription  (newsletter_id,newsletter_subscription_id) UNIQUE
#  index_newsletter_deliveries_on_newsletter_subscription_id   (newsletter_subscription_id)
#
# Foreign Keys
#
#  fk_rails_...  (newsletter_id => newsletters.id) ON DELETE => cascade
#  fk_rails_...  (newsletter_subscription_id => newsletter_subscriptions.id) ON DELETE => cascade
#
class NewsletterDeliveryTest < ActiveSupport::TestCase
  test "a newsletter is delivered to a subscriber at most once" do
    newsletter = Newsletter.create!(title: "A newsletter", subject: "A subject", content_html: "<p>Body</p>", user: users(:editor))
    subscription = newsletter_subscriptions(:active)
    NewsletterDelivery.create!(newsletter: newsletter, newsletter_subscription: subscription)

    duplicate = NewsletterDelivery.new(newsletter: newsletter, newsletter_subscription: subscription)
    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
