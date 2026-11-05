class NewsletterWelcomeJob < ApplicationJob
  queue_as :default

  def perform(subscription_id)
    subscription = NewsletterSubscription.find_by(id: subscription_id)
    return unless subscription&.subscribed?

    NewsletterMailer.welcome(subscription).deliver_now
  end
end
