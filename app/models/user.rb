class User < ApplicationRecord
  devise :database_authenticatable, :magic_link_authenticatable,
         :registerable, :recoverable, :rememberable, :validatable,
         :trackable, :confirmable

  has_many :articles, dependent: :destroy
  has_many :calendar_events, dependent: :destroy
  has_many :participants, dependent: :nullify

  ROLES = %w[regular editor admin].freeze

  enum :role, ROLES.index_with(&:itself), default: "regular"

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

  # Allow users to be created without a password when explicitly created via
  # the passwordless flow (e.g. auto-created on participant registration).
  # Regular Devise registrations still require a password.
  attr_accessor :skip_password_validation

  def password_required?
    return false if skip_password_validation

    super
  end
end
