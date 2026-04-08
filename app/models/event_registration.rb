class EventRegistration < ApplicationRecord
  belongs_to :event
  belongs_to :participant

  validates :participant_id, uniqueness: { scope: :event_id, message: "is already registered for this event" }
end
