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
    verifier.generate(NewsletterSubscription.normalize_email(email), purpose: TOKEN_PURPOSE, expires_in: LINK_EXPIRY)
  end

  def self.email_for_unsubscribe_token(token)
    verifier.verify(token, purpose: TOKEN_PURPOSE)
  end

  def self.verifier
    Rails.application.message_verifier(:newsletter_test_email_link)
  end
  private_class_method :verifier
end
