class UpdateEgc2027ScheduleV3 < ActiveRecord::Migration[8.1]
  class CalendarEvent < ActiveRecord::Base
    self.table_name = "calendar_events"
  end

  class EventGroup < ActiveRecord::Base
    self.table_name = "event_groups"
  end

  # Match the original title and both timestamps so unrelated events are never changed.
  CHANGES = [
    [["Blitz", "Blitz All"], "2027-07-25 18:00", "2027-07-25 21:30", "GoDan Blitz All", nil, nil],
    [["Blitz Finals"], "2027-07-26 18:00", "2027-07-26 21:30", "GoDan Blitz Finals", nil, nil],
    [["Group Photo", "Photo"], "2027-08-01 09:30", "2027-08-01 10:00", "Photo", "2027-08-01 13:30", "2027-08-01 14:00"],
    [["European 13x13 Championship"], "2027-08-02 18:00", "2027-08-02 22:00", "GoDan 13x13 EC", nil, nil],
    [["SC-CQ Sightseeing"], "2027-08-02 10:00", "2027-08-02 17:30", "Opening. SC Round 1-3", nil, nil],
    [["SC-CQ Welcome Party"], "2027-08-02 18:00", "2027-08-02 21:30", "SC Welcome Party", nil, "2027-08-02 20:00"],
    [["Students R1-3 / ChangQi R1", "Students R1-3 ChangQi R1"], "2027-08-03 10:00", "2027-08-03 21:30", "SC Round 4-6", nil, nil],
    [["Students R4-6 / ChangQi R2", "Students R4-6 ChangQi R2"], "2027-08-04 10:00", "2027-08-04 21:30", "SC Finals, Lectures, Simultaneous", nil, nil],
    [["Students Final / SC-CQ Simultaneous", "Students Final SC-CQ Simultaneous"], "2027-08-05 10:00", "2027-08-05 21:30", "SC Excursion to Amsterdam", nil, nil],
    [["Fun go*"], "2027-08-05 15:00", "2027-08-05 17:30", "Fun go*", "2027-08-05 18:00", "2027-08-05 22:00"],
    [["ChangQi Finals / SC-CQ Farewell dinner"], "2027-08-06 10:00", "2027-08-06 21:30", "SC Farewell dinner", "2027-08-06 18:00", "2027-08-06 20:00"],
    [["SC-CQ Departure"], "2027-08-07 10:00", "2027-08-07 13:00", "SC Departure", nil, nil]
  ].freeze

  REMOVALS = [
    ["SC-CQ Arrival", "2027-08-01 19:30", "2027-08-01 21:30"],
    ["Go Conferences", "2027-08-04 10:00", "2027-08-04 17:00"],
    ["Tsume go tmt", "2027-08-05 18:00", "2027-08-05 22:00"],
    ["Prizegiving", "2027-08-06 22:00", "2027-08-06 23:00"]
  ].freeze

  ADDITIONS = [
    ["Jonas Welticke", "2027-07-24 12:30", "2027-07-24 16:00", "entertainment"],
    ["BBQ", "2027-07-24 19:00", "2027-07-24 21:00", "entertainment"],
    ["(Beer go)", "2027-07-26 19:30", "2027-07-26 20:00", "entertainment"],
    ["Dutch dinner", "2027-07-31 17:00", "2027-07-31 19:00", "entertainment"],
    ["Beer tasting", "2027-08-03 20:00", "2027-08-03 22:00", "entertainment"],
    ["Karaoke night", "2027-08-04 21:00", "2027-08-04 23:00", "entertainment"],
    ["Lecture", "2027-08-07 13:30", "2027-08-07 14:30", "lectures"],
    ["Lecture", "2027-08-07 15:00", "2027-08-07 16:00", "lectures"]
  ].freeze

  def up
    CHANGES.each do |titles, start_time, end_time, new_title, new_start, new_end|
      matching(titles, start_time, end_time).find_each do |event|
        event.update!(title: new_title, starts_at: parse_time(new_start || start_time), ends_at: parse_time(new_end || end_time))
      end
    end

    REMOVALS.each { |title, start_time, end_time| matching(title, start_time, end_time).delete_all }

    ADDITIONS.each do |title, start_time, end_time, group_key|
      group = EventGroup.find_by!(key: group_key)
      CalendarEvent.find_or_create_by!(title: title, starts_at: parse_time(start_time), ends_at: parse_time(end_time)) do |event|
        event.event_group_id = group.id
      end
    end

    EventGroup.where(key: "student_changqi", name: ["Student and ChangQi", "Student Cup + ChangQi"]).update_all(name: "Student Cup")
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Schedule updates cannot safely restore deleted events and their attributes"
  end

  private

  def matching(title, start_time, end_time)
    CalendarEvent.where(title: title, starts_at: parse_time(start_time), ends_at: parse_time(end_time))
  end

  def parse_time(value)
    Time.zone.parse(value)
  end
end
