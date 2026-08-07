class NewsletterMailer < ApplicationMailer
  def welcome(newsletter_subscription)
    @newsletter_subscription = newsletter_subscription
    @unsubscribe_url = unsubscribe_newsletter_url(token: newsletter_subscription.unsubscribe_token)

    mail(
      to: newsletter_subscription.email,
      subject: "EGC 2027 – Welcome to the newsletter"
    )
  end
end
