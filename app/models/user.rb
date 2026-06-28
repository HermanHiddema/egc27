class User < ApplicationRecord
  devise :database_authenticatable, :magic_link_authenticatable,
         :registerable, :recoverable, :rememberable, :validatable,
         :trackable, :confirmable

  has_many :articles, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :participants, dependent: :destroy

  ROLES = %w[regular editor admin].freeze

  enum :role, ROLES.index_with(&:itself), validate: true, default: "regular"

  def after_confirmation
    super
    participants.each do |participant|
      next if participant.confirmed?

      participant.confirm!
      ParticipantMailer.registration_confirmation(participant).deliver_later if participant.email.present?
    end
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

  attr_writer :registration_participant

  def registration_participant
    @registration_participant || participants.order(created_at: :asc, id: :asc).first
  end

  def password_required?
    return false if skip_password_validation

    super
  end
end
