class AddAugust2Registration < ActiveRecord::Migration[8.1]
  class CalendarEvent < ActiveRecord::Base
    self.table_name = "calendar_events"
  end

  class EventGroup < ActiveRecord::Base
    self.table_name = "event_groups"
  end

  def up
    CalendarEvent.find_or_create_by!(
      title: "Registration",
      starts_at: Time.zone.parse("2027-08-02 09:00"),
      ends_at: Time.zone.parse("2027-08-02 09:30")
    ) do |event|
      event.event_group_id = EventGroup.find_or_create_by!(key: "registration") do |group|
        group.name = "Registration"
        group.color = "#b7b7b7"
      end.id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot safely determine whether the registration event existed before this migration"
  end
end
