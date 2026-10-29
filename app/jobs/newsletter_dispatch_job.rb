class NewsletterDispatchJob < ApplicationJob
  queue_as :default

  def perform(newsletter_id)
    newsletter = Newsletter.find_by(id: newsletter_id)
    return unless newsletter&.sent?

    NewsletterSubscription.where(subscribed: true).in_batches do |subscriptions|
      timestamp = Time.current
      rows = subscriptions.pluck(:id).map do |subscription_id|
        { newsletter_id: newsletter.id, newsletter_subscription_id: subscription_id, created_at: timestamp, updated_at: timestamp }
      end
      NewsletterDelivery.insert_all(rows, unique_by: [:newsletter_id, :newsletter_subscription_id]) if rows.any?
    end

    newsletter.newsletter_deliveries.pending.find_each do |delivery|
      NewsletterDeliveryJob.perform_later(delivery.id)
    end
  end
end
