require "test_helper"
require Rails.root.join("db/migrate/20261104120000_update_egc_2027_schedule_v3").to_s

class UpdateEgc2027ScheduleV3Test < ActiveSupport::TestCase
  test "updates matching events in place and leaves similarly named events alone" do
    EventGroup.find_or_create_by!(key: "entertainment") { |group| group.name = "Entertainment" }
    EventGroup.find_or_create_by!(key: "lectures") { |group| group.name = "Lectures" }
    group = EventGroup.create!(key: "student_changqi", name: "Student and ChangQi")
    photo = CalendarEvent.create!(title: "Group Photo", starts_at: "2027-08-01 09:30", ends_at: "2027-08-01 10:00", location: "Main hall", description: "Bring a camera", event_group: group)
    other = CalendarEvent.create!(title: "Group Photo", starts_at: "2028-08-01 09:30", ends_at: "2028-08-01 10:00")
    different_time = CalendarEvent.create!(title: "Prizegiving", starts_at: "2027-08-06 21:00", ends_at: "2027-08-06 23:00")
    removed = CalendarEvent.create!(title: "Prizegiving", starts_at: "2027-08-06 22:00", ends_at: "2027-08-06 23:00")

    migration = UpdateEgc2027ScheduleV3.new
    migration.up
    migration.up

    assert_equal "Photo", photo.reload.title
    assert_equal Time.zone.parse("2027-08-01 13:30"), photo.starts_at
    assert_equal Time.zone.parse("2027-08-01 14:00"), photo.ends_at
    assert_equal "Main hall", photo.location
    assert_equal "Bring a camera", photo.description
    assert_equal group.id, photo.event_group_id
    assert_equal "Student Cup", group.reload.name
    assert_equal "Group Photo", other.reload.title
    assert different_time.reload.persisted?
    assert_not CalendarEvent.exists?(removed.id)
    assert_equal 1, CalendarEvent.where(title: "Beer tasting", starts_at: Time.zone.parse("2027-08-03 20:00")).count
    assert_equal 2, CalendarEvent.where(title: "Lecture", starts_at: [Time.zone.parse("2027-08-07 13:30"), Time.zone.parse("2027-08-07 15:00")]).count
  end
end
