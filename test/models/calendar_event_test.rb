require "test_helper"

class CalendarEventTest < ActiveSupport::TestCase
  test "is invalid when end time is before start time" do
    calendar_event = CalendarEvent.new(
      title: "Invalid Event",
      starts_at: Time.zone.parse("2026-07-20 14:00"),
      ends_at: Time.zone.parse("2026-07-20 13:00")
    )

    assert_not calendar_event.valid?
    assert_includes calendar_event.errors[:ends_at], "must be the same time or after the start"
  end

  test "is invalid with non-hex color" do
    calendar_event = CalendarEvent.new(
      title: "Invalid Color Event",
      starts_at: Time.zone.parse("2026-07-20 14:00"),
      ends_at: Time.zone.parse("2026-07-20 15:00"),
      color: "red"
    )

    assert_not calendar_event.valid?
    assert_includes calendar_event.errors[:color], "is invalid"
  end

  test "allows blank color override" do
    calendar_event = CalendarEvent.new(
      title: "Group Color Event",
      starts_at: Time.zone.parse("2026-07-20 14:00"),
      ends_at: Time.zone.parse("2026-07-20 15:00"),
      color: nil
    )

    assert calendar_event.valid?
  end

  test "normalizes blank color override to nil" do
    calendar_event = CalendarEvent.create!(
      title: "Blank Color Event",
      starts_at: Time.zone.parse("2026-07-20 14:00"),
      ends_at: Time.zone.parse("2026-07-20 15:00"),
      color: ""
    )

    assert_nil calendar_event.reload.color
  end
end
