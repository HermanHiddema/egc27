# == Schema Information
#
# Table name: event_registrations
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  event_id       :bigint           not null
#  participant_id :bigint           not null
#
# Indexes
#
#  index_event_registrations_on_event_id                     (event_id)
#  index_event_registrations_on_event_id_and_participant_id  (event_id,participant_id) UNIQUE
#  index_event_registrations_on_participant_id               (participant_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (participant_id => participants.id)
#
class EventRegistration < ApplicationRecord
  belongs_to :event
  belongs_to :participant

  validates :participant_id, uniqueness: { scope: :event_id, message: "is already registered for this event" }
end
