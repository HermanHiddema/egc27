class NewsletterGoodbyeJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.seconds, attempts: 5

  def perform(subscription_id, resubscribe_token)
    subscription = NewsletterSubscription.find_by(id: subscription_id)
    return unless subscription

    NewsletterMailer.goodbye(subscription, resubscribe_token: resubscribe_token).deliver_now
  end
end
