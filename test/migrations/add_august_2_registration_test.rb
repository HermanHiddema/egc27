require "test_helper"
require Rails.root.join("db/migrate/20261104130000_add_august_2_registration").to_s

class AddAugust2RegistrationTest < ActiveSupport::TestCase
  test "adds the registration event once and leaves other registrations unchanged" do
    group = EventGroup.find_or_create_by!(key: "registration") { |record| record.name = "Registration" }
    other = CalendarEvent.create!(title: "Registration", starts_at: "2027-08-02 09:00", ends_at: "2027-08-02 10:00")

    2.times { AddAugust2Registration.new.up }

    events = CalendarEvent.where(title: "Registration", starts_at: Time.zone.parse("2027-08-02 09:00"), ends_at: Time.zone.parse("2027-08-02 09:30"))
    assert_equal 1, events.count
    assert_equal group.id, events.first.event_group_id
    assert other.reload.persisted?
  end
end
