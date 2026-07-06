# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  full_name              :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  magic_link_token       :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :string           default("regular"), not null
#  sign_in_count          :integer          default(0), not null
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  devise :database_authenticatable, :magic_link_authenticatable,
         :registerable, :recoverable, :rememberable, :validatable,
         :trackable, :confirmable

  has_many :articles, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :participants, dependent: :destroy

  ROLES = %w[regular editor admin].freeze

  enum :role, ROLES.index_with(&:itself), validate: true, default: "regular"

  after_update :propagate_email_change, if: :saved_change_to_email?

  def after_confirmation
    super
    participants.each do |participant|
      next if participant.confirmed?

      participant.confirm!
      ParticipantMailer.registration_confirmation(participant).deliver_later if participant.email.present?
    end
    NewsletterSubscription.subscribe_user(self)
  end

  # Invalidate the magic link after a successful sign-in so each link works
  # exactly once. See MagicLink::SingleUseTokenizer.
  def after_magic_link_authentication
    update_column(:magic_link_token, nil) if magic_link_token.present?
  end

  scope :ordered_by_name, -> { order(full_name: :asc) }

  def display_name
    full_name.presence || email
  end

  def can_create?
    editor? || admin?
  end

  def can_edit?
    editor? || admin?
  end

  def can_delete?
    admin?
  end

  def password_set?
    encrypted_password.present?
  end

  # Allow users to be created without a password when explicitly created via
  # the passwordless flow (e.g. auto-created on participant registration).
  # Regular Devise registrations still require a password.
  attr_accessor :skip_password_validation

  validates :password, confirmation: true, if: :password_present?

  attr_writer :registration_participant

  def registration_participant
    @registration_participant || participants.order(created_at: :asc, id: :asc).first
  end

  def password_required?
    return false if skip_password_validation && password.blank?

    super
  end

  def password_present?
    password.present?
  end

  private

  def propagate_email_change
    old_email, new_email = saved_change_to_email
    normalized_email = NewsletterSubscription.normalize_email(new_email)

    participants.update_all(email: normalized_email, updated_at: Time.current)
    NewsletterSubscription.update_email(old_email, normalized_email) if participants.exists?
  end
end
