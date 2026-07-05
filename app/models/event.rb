# == Schema Information
#
# Table name: events
#
#  id          :bigint           not null, primary key
#  description :text
#  ends_at     :datetime         not null
#  location    :string
#  starts_at   :datetime         not null
#  title       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_events_on_ends_at    (ends_at)
#  index_events_on_starts_at  (starts_at)
#  index_events_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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
