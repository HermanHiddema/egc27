class RenameEventsToCalendarEvents < ActiveRecord::Migration[8.1]
  def change
    rename_table :events, :calendar_events
  end
end
