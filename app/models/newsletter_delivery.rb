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
class NewsletterDelivery < ApplicationRecord
  belongs_to :newsletter
  belongs_to :newsletter_subscription

  scope :pending, -> { where(delivered_at: nil) }

  validates :newsletter_subscription_id, uniqueness: { scope: :newsletter_id }
end
