class EventRegistration < ApplicationRecord
  belongs_to :event
  belongs_to :participant

  validates :event_id, uniqueness: { scope: :participant_id, message: "participant is already registered for this event" }
end
