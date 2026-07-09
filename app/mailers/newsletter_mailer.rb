class NewsletterMailer < ApplicationMailer
  def goodbye(newsletter_subscription)
    @newsletter_subscription = newsletter_subscription
    @resubscribe_url = resubscribe_newsletter_url(newsletter_subscription.unsubscribe_token)

    mail(
      to: newsletter_subscription.email,
      subject: "EGC 2027 – You have been unsubscribed"
    )
  end
end
