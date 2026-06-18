class EventGroup < ApplicationRecord
  has_many :calendar_events, dependent: :nullify

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
end
