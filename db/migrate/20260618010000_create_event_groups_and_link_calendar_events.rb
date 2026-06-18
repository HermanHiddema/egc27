class CreateEventGroupsAndLinkCalendarEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :event_groups do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :color

      t.timestamps
    end

    add_index :event_groups, :key, unique: true

    add_reference :calendar_events, :event_group, foreign_key: true
    remove_column :calendar_events, :event_group, :string
  end
end
