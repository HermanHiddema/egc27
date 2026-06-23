class UpdateSeedEventsScheduleV2 < ActiveRecord::Migration[8.1]
  DEFAULT_EVENT_COLOR = "#dbeafe"

  EVENT_GROUP_ATTRIBUTES = {
    "registration"          => { name: "Registration",              color: "#b7b7b7" },
    "ceremony"              => { name: "Ceremony and Official",     color: "#ffd966" },
    "main_open"             => { name: "Main Open",                 color: "#c9daf8" },
    "european_championship" => { name: "European Championship",     color: "#d5a6bd" },
    "rapid"                 => { name: "Rapid",                     color: "#00ffff" },
    "senior"                => { name: "Senior Tournament",         color: "#f4cccc" },
    "women"                 => { name: "Women Tournament",          color: "#f4cccc" },
    "team"                  => { name: "Team Tournament",           color: "#f4cccc" },
    "youth"                 => { name: "Youth Tournament",          color: "#f4cccc" },
    "pair_go"               => { name: "Pair Go",                   color: "#f4cccc" },
    "weekend"               => { name: "Weekend Tournament",        color: "#c9daf8" },
    "other_side_tournaments" => { name: "Other Side Tournaments",   color: "#f4cccc" },
    "professional"          => { name: "Professional Activities",   color: "#b6d7a8" },
    "lectures"              => { name: "Lectures",                  color: "#fff2cc" },
    "panda_team"            => { name: "Panda Team",                color: "#ff00ff" },
    "fun_go"                => { name: "Fun Go",                    color: "#e06666" },
    "excursions"            => { name: "Excursions",                color: "#6fa8dc" },
    "entertainment"         => { name: "Entertainment",             color: "#6fa8dc" },
    "student_changqi"       => { name: "Student and ChangQi",       color: "#00ff00" },
    "other"                 => { name: "Other",                     color: DEFAULT_EVENT_COLOR }
  }.freeze

  class EventGroup < ActiveRecord::Base
    self.table_name = "event_groups"
  end

  class CalendarEvent < ActiveRecord::Base
    self.table_name = "calendar_events"
  end

  EVENTS_TO_CREATE = [
    { title: "Blitz", starts_at: "2027-07-25 18:00", ends_at: "2027-07-25 21:30" },
    { title: "Simultaneous games", starts_at: "2027-07-25 18:00", ends_at: "2027-07-25 20:00" },
    { title: "Blitz Finals", starts_at: "2027-07-26 18:00", ends_at: "2027-07-26 21:30" },
    { title: "Senior Tmt R1", starts_at: "2027-07-26 18:00", ends_at: "2027-07-26 19:30" },
    { title: "Senior Tmt R2", starts_at: "2027-07-26 20:30", ends_at: "2027-07-26 22:00" },
    { title: "Youth tmt R1", starts_at: "2027-07-26 18:00", ends_at: "2027-07-26 19:30" },
    { title: "Youth tmt R2", starts_at: "2027-07-26 20:30", ends_at: "2027-07-26 22:00" },
    { title: "Fun go*", starts_at: "2027-07-27 15:00", ends_at: "2027-07-27 17:30" },
    { title: "Senior Tmt R3", starts_at: "2027-07-27 18:00", ends_at: "2027-07-27 19:30" },
    { title: "Senior Tmt R4", starts_at: "2027-07-27 20:30", ends_at: "2027-07-27 22:00" },
    { title: "Youth tmt R3", starts_at: "2027-07-27 18:00", ends_at: "2027-07-27 19:30" },
    { title: "Youth tmt R4", starts_at: "2027-07-27 20:30", ends_at: "2027-07-27 22:00" },
    { title: "Joanna Koike", starts_at: "2027-07-27 22:00", ends_at: "2027-07-27 23:00" },
    { title: "Nations Cup R1", starts_at: "2027-07-29 18:00", ends_at: "2027-07-29 19:30" },
    { title: "Nations Cup R2", starts_at: "2027-07-29 20:30", ends_at: "2027-07-29 22:00" },
    { title: "Fun go*", starts_at: "2027-07-29 18:00", ends_at: "2027-07-29 20:30" },
    { title: "Nations Cup R3", starts_at: "2027-07-30 18:00", ends_at: "2027-07-30 19:30" },
    { title: "Nations Cup R4", starts_at: "2027-07-30 20:30", ends_at: "2027-07-30 22:00" },
    { title: "Reunion of Dutch Go Players", starts_at: "2027-08-01 16:00", ends_at: "2027-08-01 22:30" },
    { title: "Main Open R6", starts_at: "2027-08-02 10:00", ends_at: "2027-08-02 14:30" },
    { title: "Fun go*", starts_at: "2027-08-02 15:00", ends_at: "2027-08-02 17:30" },
    { title: "Game reviews by professionals", starts_at: "2027-08-02 12:00", ends_at: "2027-08-02 17:30" },
    { title: "Lecture", starts_at: "2027-08-02 13:30", ends_at: "2027-08-02 14:30" },
    { title: "Lecture", starts_at: "2027-08-02 15:00", ends_at: "2027-08-02 16:00" },
    { title: "Women tmt R1", starts_at: "2027-08-02 18:00", ends_at: "2027-08-02 19:30" },
    { title: "Women tmt R2", starts_at: "2027-08-02 20:30", ends_at: "2027-08-02 22:00" },
    { title: "Women tmt R3", starts_at: "2027-08-03 18:00", ends_at: "2027-08-03 19:30" },
    { title: "Women tmt R4", starts_at: "2027-08-03 20:30", ends_at: "2027-08-03 22:00" },
    { title: "Rapid R8", starts_at: "2027-08-05 15:00", ends_at: "2027-08-05 16:30" },
    { title: "Fun go*", starts_at: "2027-08-06 18:00", ends_at: "2027-08-06 22:00" },
    { title: "Rapid R9", starts_at: "2027-08-06 15:00", ends_at: "2027-08-06 16:30" }
  ].freeze

  EVENTS_TO_DELETE = [
    { title: "Senior Tmt R1", starts_at: "2027-07-25 17:30", ends_at: "2027-07-25 19:00", color: "#f4cccc" },
    { title: "Senior Tmt R2", starts_at: "2027-07-25 20:00", ends_at: "2027-07-25 21:30", color: "#f4cccc" },
    { title: "Senior Tmt R3", starts_at: "2027-07-26 17:30", ends_at: "2027-07-26 19:00", color: "#f4cccc" },
    { title: "Senior Tmt R4", starts_at: "2027-07-26 20:00", ends_at: "2027-07-26 21:30", color: "#f4cccc" },
    { title: "Blitz", starts_at: "2027-07-27 16:00", ends_at: "2027-07-27 23:00", color: "#f4cccc" },
    { title: "Joanna Koike", starts_at: "2027-07-27 20:00", ends_at: "2027-07-27 21:30", color: "#6fa8dc" },
    { title: "Women tmt R1", starts_at: "2027-07-28 10:00", ends_at: "2027-07-28 12:00", color: "#f4cccc" },
    { title: "Women tmt R2", starts_at: "2027-07-28 12:30", ends_at: "2027-07-28 14:30", color: "#f4cccc" },
    { title: "Women tmt R3", starts_at: "2027-07-28 15:00", ends_at: "2027-07-28 17:00", color: "#f4cccc" },
    { title: "Women tmt R4", starts_at: "2027-07-28 18:00", ends_at: "2027-07-28 20:00", color: "#f4cccc" },
    { title: "Fun go*", starts_at: "2027-07-29 15:00", ends_at: "2027-07-29 17:30", color: "#e06666" },
    { title: "Team Tmt R1", starts_at: "2027-07-29 17:30", ends_at: "2027-07-29 19:00", color: "#f4cccc" },
    { title: "Team Tmt R2", starts_at: "2027-07-29 20:00", ends_at: "2027-07-29 21:30", color: "#f4cccc" },
    { title: "Team Tmt R3", starts_at: "2027-07-30 17:30", ends_at: "2027-07-30 19:00", color: "#f4cccc" },
    { title: "Team Tmt R4", starts_at: "2027-07-30 20:00", ends_at: "2027-07-30 21:30", color: "#f4cccc" },
    { title: "Registration", starts_at: "2027-08-02 09:00", ends_at: "2027-08-02 10:00", color: "#b7b7b7" },
    { title: "Main Open R6", starts_at: "2027-08-02 11:00", ends_at: "2027-08-02 15:30", color: "#c9daf8" },
    { title: "Game reviews by professionals", starts_at: "2027-08-02 13:00", ends_at: "2027-08-02 17:30", color: "#b6d7a8" },
    { title: "Lecture", starts_at: "2027-08-02 14:30", ends_at: "2027-08-02 15:30", color: "#fff2cc" },
    { title: "Lecture", starts_at: "2027-08-02 16:00", ends_at: "2027-08-02 17:00", color: "#fff2cc" },
    { title: "Youth tmt R1", starts_at: "2027-08-04 10:00", ends_at: "2027-08-04 12:00", color: "#f4cccc" },
    { title: "Poker tmt", starts_at: "2027-08-04 10:00", ends_at: "2027-08-04 21:00", color: "#6fa8dc" },
    { title: "Youth tmt R2", starts_at: "2027-08-04 12:30", ends_at: "2027-08-04 14:30", color: "#f4cccc" },
    { title: "Youth tmt R3", starts_at: "2027-08-04 15:00", ends_at: "2027-08-04 17:00", color: "#f4cccc" },
    { title: "Youth tmt R4", starts_at: "2027-08-04 19:00", ends_at: "2027-08-04 21:00", color: "#f4cccc" },
    { title: "Rapid R8", starts_at: "2027-08-05 16:00", ends_at: "2027-08-05 17:30", color: "#00ffff" },
    { title: "Fun go*", starts_at: "2027-08-06 15:00", ends_at: "2027-08-06 17:30", color: "#e06666" },
    { title: "Rapid R9", starts_at: "2027-08-06 16:00", ends_at: "2027-08-06 17:30", color: "#00ffff" }
  ].freeze

  EVENTS_TO_UPDATE_ENDS_AT = [
    { title: "Prizegiving", starts_at: "2027-08-04 21:00", old_ends_at: "2027-08-04 21:30", new_ends_at: "2027-08-04 22:00" },
    { title: "Game reviews by professionals", starts_at: "2027-08-07 12:00", old_ends_at: "2027-08-07 17:30", new_ends_at: "2027-08-07 15:30" }
  ].freeze

  def up
    event_groups_by_key = find_or_create_event_groups

    EVENTS_TO_DELETE.each do |event_data|
      CalendarEvent.where(title: event_data[:title], starts_at: parse_time(event_data[:starts_at])).delete_all
    end

    EVENTS_TO_UPDATE_ENDS_AT.each do |event_data|
      event = CalendarEvent.find_by(title: event_data[:title], starts_at: parse_time(event_data[:starts_at]))
      next unless event

      event.update!(ends_at: parse_time(event_data[:new_ends_at]))
    end

    EVENTS_TO_CREATE.each do |event_data|
      upsert_event(event_data, event_groups_by_key)
    end
  end

  def down
    event_groups_by_key = find_or_create_event_groups

    EVENTS_TO_CREATE.each do |event_data|
      CalendarEvent.where(title: event_data[:title], starts_at: parse_time(event_data[:starts_at])).delete_all
    end

    EVENTS_TO_UPDATE_ENDS_AT.each do |event_data|
      event = CalendarEvent.find_by(title: event_data[:title], starts_at: parse_time(event_data[:starts_at]))
      next unless event

      event.update!(ends_at: parse_time(event_data[:old_ends_at]))
    end

    EVENTS_TO_DELETE.each do |event_data|
      upsert_event(event_data, event_groups_by_key)
    end
  end

  private

  def upsert_event(event_data, event_groups_by_key)
    event = CalendarEvent.find_or_initialize_by(
      title: event_data[:title],
      starts_at: parse_time(event_data[:starts_at])
    )

    event_group_key = event_group_key_for(event_data[:title], event_data[:color] || DEFAULT_EVENT_COLOR)
    event_group = event_groups_by_key.fetch(event_group_key) do
      raise ActiveRecord::MigrationError, "EventGroup with key #{event_group_key.inspect} not found. " \
        "Ensure it is present in EVENT_GROUP_ATTRIBUTES and has been seeded."
    end
    explicit_color = event_data[:color]

    event.ends_at = parse_time(event_data[:ends_at])
    event.event_group_id = event_group.id
    event.color = if explicit_color.present? && explicit_color.downcase != event_group.color.to_s.downcase
      explicit_color
    end
    event.save!
  end

  def parse_time(time_string)
    Time.zone.parse(time_string)
  end

  def find_or_create_event_groups
    event_group_keys.each_with_object({}) do |key, memo|
      attrs = EVENT_GROUP_ATTRIBUTES.fetch(key) do
        raise ActiveRecord::MigrationError, "Unknown event group key: #{key.inspect}. Add it to EVENT_GROUP_ATTRIBUTES."
      end
      memo[key] = EventGroup.find_or_create_by!(key: key) do |eg|
        eg.name = attrs[:name]
        eg.color = attrs[:color]
      end
    end
  end

  def event_group_keys
    @event_group_keys ||= (
      EVENTS_TO_CREATE.map { |event_data| event_group_key_for(event_data[:title], event_data[:color] || DEFAULT_EVENT_COLOR) } +
      EVENTS_TO_DELETE.map { |event_data| event_group_key_for(event_data[:title], event_data[:color] || DEFAULT_EVENT_COLOR) }
    ).uniq
  end

  def event_group_key_for(title, color)
    normalized_title = title.to_s.downcase
    normalized_color = color.to_s.downcase

    case normalized_title
    when /\Apair go\b/
      "pair_go"
    when /\Ayouth tmt\b/
      "youth"
    when /\Awomen tmt\b/
      "women"
    when /\Asenior tmt\b/
      "senior"
    when /\Ateam tmt\b|\Anations cup\b/
      "team"
    when /\Aweekend tmt\b/
      "weekend"
    when /\Amain open\b/
      "main_open"
    when /\Aeuropean championship\b/
      "european_championship"
    when /\Arapid\b/
      "rapid"
    when /\Aregistration\b/
      "registration"
    when /\Aopening ceremony\b|\Avip dinner\b|\Aegf annual general meeting\b|\Aprizegiving\b|\Aclosing with prizegiving\b|\Agroup photo\b/
      "ceremony"
    when /professional|simultaneous games|game reviews/
      "professional"
    when /\Alecture\b/
      "lectures"
    when /\Apanda team\b/
      "panda_team"
    when /\Afun go\*/
      "fun_go"
    when /students|changqi|sc-cq/
      "student_changqi"
    when /\Aexcursions\b/
      "excursions"
    when /\Apoker tmt\b|\Amagic the gathering tmt\b|\Ago conferences\b|\Ajoanna koike\b|\Areunion of dutch go players\b/
      "entertainment"
    when /\Ablitz\b|\Ablitz finals\b|\Atsume go tmt\b|\Aeuropean 13x13 championship\b|\Aeuropean 9x9 championship\b/
      "other_side_tournaments"
    else
      case normalized_color
      when "#f4cccc"
        "other_side_tournaments"
      when "#6fa8dc"
        "entertainment"
      when "#00ff00"
        "student_changqi"
      else
        "other"
      end
    end
  end
end
