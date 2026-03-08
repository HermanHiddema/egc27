require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "is invalid when end time is before start time" do
    event = Event.new(
      title: "Invalid Event",
      starts_at: Time.zone.parse("2026-07-20 14:00"),
      ends_at: Time.zone.parse("2026-07-20 13:00"),
      user: users(:one)
    )

    assert_not event.valid?
    assert_includes event.errors[:ends_at], "must be the same time or after the start"
  end
end
