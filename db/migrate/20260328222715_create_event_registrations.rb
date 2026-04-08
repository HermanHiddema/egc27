class CreateEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :event_registrations do |t|
      t.references :event, null: false, foreign_key: true
      t.references :participant, null: false, foreign_key: true

      t.timestamps
    end

    add_index :event_registrations, [:event_id, :participant_id], unique: true
  end
end
