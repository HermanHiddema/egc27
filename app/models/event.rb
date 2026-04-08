class Event < ApplicationRecord
  belongs_to :user
  has_many :event_registrations, dependent: :destroy
  has_many :participants, through: :event_registrations

  validates :title, presence: true
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validate :ends_at_after_starts_at

  scope :chronological, -> { order(:starts_at, :id) }

  private

  def ends_at_after_starts_at
    return unless starts_at.present? && ends_at.present?

    errors.add(:ends_at, "must be after start time") if ends_at < starts_at
  end
end
