class CalendarEvent < ApplicationRecord
  belongs_to :user

  validates :title, :starts_at, :ends_at, presence: true
  validate :ends_at_not_before_starts_at

  scope :chronological, -> { order(:starts_at, :id) }

  private

  def ends_at_not_before_starts_at
    return if starts_at.blank? || ends_at.blank? || ends_at >= starts_at

    errors.add(:ends_at, "must be the same time or after the start")
  end
end
