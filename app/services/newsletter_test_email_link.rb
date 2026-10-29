class NewsletterTestEmailLink
  TOKEN_PURPOSE = :newsletter_test_email_link
  LINK_EXPIRY = 30.days

  def self.preview_token(newsletter)
    newsletter.signed_id(purpose: TOKEN_PURPOSE, expires_in: LINK_EXPIRY)
  end

  def self.find_preview_newsletter(token)
    Newsletter.find_signed!(token, purpose: TOKEN_PURPOSE)
  end

  def self.unsubscribe_token(email)
    subscription = NewsletterSubscription.find_by(
      email: NewsletterSubscription.normalize_email(email),
      subscribed: true
    )
    one_time_token = subscription&.unsubscribe_token || SecureRandom.urlsafe_base64(24)

    verifier.generate(one_time_token, purpose: TOKEN_PURPOSE, expires_in: LINK_EXPIRY)
  end

  def self.subscription_for_unsubscribe_token(token)
    unsubscribe_token = verifier.verify(token, purpose: TOKEN_PURPOSE)
    NewsletterSubscription.find_by(unsubscribe_token: unsubscribe_token) if unsubscribe_token.present?
  end

  def self.verifier
    Rails.application.message_verifier(:newsletter_test_email_link)
  end
  private_class_method :verifier
end
