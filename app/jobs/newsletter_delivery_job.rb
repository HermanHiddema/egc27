class NewsletterDeliveryJob < ApplicationJob
  queue_as :default

  def perform(delivery_id)
    delivery = NewsletterDelivery.includes(:newsletter, :newsletter_subscription).find_by(id: delivery_id)
    return unless delivery&.newsletter&.sent? && delivery.newsletter_subscription&.subscribed?

    claimed_at = Time.current
    claimed = NewsletterDelivery.where(id: delivery.id, delivered_at: nil).update_all(delivered_at: claimed_at, updated_at: claimed_at)
    return unless claimed == 1

    begin
      NewsletterMailer.newsletter(delivery.newsletter, delivery.newsletter_subscription).deliver_now
    rescue StandardError
      NewsletterDelivery.where(id: delivery.id, delivered_at: claimed_at).update_all(delivered_at: nil, updated_at: Time.current)
      raise
    end
  end
end
