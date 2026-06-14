class User < ApplicationRecord
  devise :database_authenticatable, :magic_link_authenticatable,
         :registerable, :recoverable, :rememberable, :validatable,
         :trackable, :confirmable

  has_many :articles, dependent: :destroy
  has_many :calendar_events, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :participants, dependent: :nullify

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

  def password_required?
    return false if skip_password_validation

    super
  end
end
