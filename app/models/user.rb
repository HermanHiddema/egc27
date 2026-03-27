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

  # Allow users to be created without a password (e.g. auto-created on
  # participant registration). They can sign in via magic link and
  # optionally set a password later via the forgot-password flow.
  def password_required?
    password.present? || password_confirmation.present?
  end
end
