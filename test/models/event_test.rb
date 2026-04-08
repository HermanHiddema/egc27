require "test_helper"

class EventTest < ActiveSupport::TestCase
  def valid_event_attributes
    {
      title: "Test Event",
      starts_at: Time.zone.parse("2026-08-01 10:00"),
      ends_at: Time.zone.parse("2026-08-01 12:00"),
      user: users(:admin)
    }
  end

  test "is valid with required attributes" do
    event = Event.new(valid_event_attributes)
    assert event.valid?
  end

  test "requires title" do
    event = Event.new(valid_event_attributes.merge(title: nil))
    assert_not event.valid?
    assert_includes event.errors[:title], "can't be blank"
  end

  test "requires starts_at" do
    event = Event.new(valid_event_attributes.merge(starts_at: nil))
    assert_not event.valid?
    assert_includes event.errors[:starts_at], "can't be blank"
  end

  test "requires ends_at" do
    event = Event.new(valid_event_attributes.merge(ends_at: nil))
    assert_not event.valid?
    assert_includes event.errors[:ends_at], "can't be blank"
  end

  test "requires ends_at to be after starts_at" do
    event = Event.new(valid_event_attributes.merge(
      starts_at: Time.zone.parse("2026-08-01 12:00"),
      ends_at: Time.zone.parse("2026-08-01 10:00")
    ))
    assert_not event.valid?
    assert_includes event.errors[:ends_at], "must be after start time"
  end

  test "allows ends_at equal to starts_at" do
    time = Time.zone.parse("2026-08-01 10:00")
    event = Event.new(valid_event_attributes.merge(starts_at: time, ends_at: time))
    assert event.valid?
  end

  test "has many participants through event_registrations" do
    event = events(:one)
    assert_includes event.participants, participants(:one)
  end

  test "chronological scope orders by starts_at" do
    events = Event.chronological
    starts = events.map(&:starts_at)
    assert_equal starts, starts.sort
  end
end
