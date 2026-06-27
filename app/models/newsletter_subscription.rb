class NewsletterSubscription < ApplicationRecord
  before_validation :normalize_fields
  before_validation :ensure_unsubscribe_token
  before_save :sync_unsubscribed_at

  validates :first_name, :last_name, :email, :unsubscribe_token, presence: true
  validates :email, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subscribed, inclusion: { in: [true, false] }

  def self.normalize_email(email)
    email.to_s.strip.downcase
  end

  def self.subscribe_user(user)
    return if user.nil?

    participant = user.participants.order(:id).first
    return if participant.nil?

    email = normalize_email(user.email)
    return if email.blank?
    return if exists?(email: email)

    create(
      first_name: participant.first_name,
      last_name: participant.last_name,
      email: email
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def unsubscribe!
    update!(subscribed: false)
  end

  private

  def normalize_fields
    self.first_name = first_name.to_s.strip
    self.last_name = last_name.to_s.strip
    self.email = self.class.normalize_email(email)
  end

  def ensure_unsubscribe_token
    self.unsubscribe_token = SecureRandom.urlsafe_base64(24) if unsubscribe_token.blank?
  end

  def sync_unsubscribed_at
    if subscribed_changed?
      if subscribed?
        self.unsubscribed_at = nil
      elsif unsubscribed_at.nil?
        self.unsubscribed_at = Time.current
      end
    end
  end
end
