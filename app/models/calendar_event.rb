class CalendarEvent < ApplicationRecord
  DEFAULT_COLOR = "#dbeafe".freeze

  belongs_to :event_group, optional: true

  normalizes :color, with: ->(value) { value.presence }

  validates :title, :starts_at, :ends_at, presence: true
  validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validate :ends_at_not_before_starts_at

  scope :chronological, -> { order(:starts_at, :id) }

  def effective_color
    color.presence || event_group&.color.presence || DEFAULT_COLOR
  end

  private

  def ends_at_not_before_starts_at
    return if starts_at.blank? || ends_at.blank? || ends_at >= starts_at

    errors.add(:ends_at, "must be the same time or after the start")
  end
end
