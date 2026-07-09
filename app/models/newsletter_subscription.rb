# == Schema Information
#
# Table name: newsletter_subscriptions
#
#  id                :bigint           not null, primary key
#  email             :string           not null
#  first_name        :string           not null
#  last_name         :string           not null
#  subscribed        :boolean          default(TRUE), not null
#  unsubscribe_token :string           not null
#  unsubscribed_at   :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_newsletter_subscriptions_on_email              (email) UNIQUE
#  index_newsletter_subscriptions_on_unsubscribe_token  (unsubscribe_token) UNIQUE
#
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

    participant = user.registration_participant
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

  def self.update_email(old_email, new_email)
    old = normalize_email(old_email)
    new = normalize_email(new_email)
    return if old.blank? || new.blank? || old == new

    subscription = find_by(email: old)
    return if subscription.nil?

    if exists?(email: new)
      subscription.destroy
      return
    end

    subscription.update(email: new)
  rescue ActiveRecord::RecordNotUnique
    subscription&.destroy
  end

  def unsubscribe!
    update!(subscribed: false)
  end

  def resubscribe!
    update!(subscribed: true)
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
