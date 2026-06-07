class NewsletterSubscription < ApplicationRecord
  before_validation :normalize_fields
  before_validation :ensure_unsubscribe_token

  validates :first_name, :last_name, :email, :unsubscribe_token, presence: true
  validates :email, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subscribed, inclusion: { in: [true, false] }

  def unsubscribe!
    update!(subscribed: false, unsubscribed_at: Time.current)
  end

  private

  def normalize_fields
    self.first_name = first_name.to_s.strip
    self.last_name = last_name.to_s.strip
    self.email = email.to_s.strip.downcase
  end

  def ensure_unsubscribe_token
    self.unsubscribe_token = SecureRandom.urlsafe_base64(24) if unsubscribe_token.blank?
  end
end
