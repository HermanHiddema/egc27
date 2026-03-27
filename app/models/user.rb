class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable

  has_many :articles, dependent: :destroy
  has_many :calendar_events, dependent: :destroy

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
end
