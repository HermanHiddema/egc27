class AddEventGroupToCalendarEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :calendar_events, :event_group, :string, null: false, default: "other"
    add_index :calendar_events, :event_group
  end
end
