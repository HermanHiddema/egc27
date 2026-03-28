require "test_helper"

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
    assert registration.errors[:event_id].present?
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
