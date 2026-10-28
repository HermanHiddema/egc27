class NewsletterDispatchJob < ApplicationJob
  queue_as :default

  def perform(newsletter_id)
    newsletter = Newsletter.find_by(id: newsletter_id)
    return unless newsletter&.sent?

    NewsletterSubscription.where(subscribed: true).find_each do |subscription|
      NewsletterDeliveryJob.perform_later(newsletter.id, subscription.id)
    end
  end
end
