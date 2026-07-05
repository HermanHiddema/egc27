require "test_helper"

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
