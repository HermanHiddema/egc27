class NewsletterDeliveryJob < ApplicationJob
  queue_as :default

  def perform(newsletter_id, subscription_id)
    newsletter = Newsletter.find_by(id: newsletter_id)
    subscription = NewsletterSubscription.find_by(id: subscription_id, subscribed: true)
    return unless newsletter&.sent? && subscription

    NewsletterMailer.newsletter(newsletter, subscription).deliver_now
  end
end
