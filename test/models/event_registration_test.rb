require "test_helper"

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
class EventRegistrationTest < ActiveSupport::TestCase
  test "is valid with event and participant" do
    registration = EventRegistration.new(
      event: events(:two),
      participant: participants(:one)
    )
    assert registration.valid?
  end

  test "prevents duplicate registrations for same event and participant" do
    registration = EventRegistration.new(
      event: events(:one),
      participant: participants(:one)
    )
    assert_not registration.valid?
    assert registration.errors[:participant_id].present?
  end

  test "allows same participant to register for different events" do
    registration = EventRegistration.new(
      event: events(:two),
      participant: participants(:one)
    )
    assert registration.valid?
  end

  test "allows different participants to register for same event" do
    registration = EventRegistration.new(
      event: events(:one),
      participant: participants(:two)
    )
    assert registration.valid?
  end
end
