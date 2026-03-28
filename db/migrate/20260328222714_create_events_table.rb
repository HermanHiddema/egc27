class CreateEventsTable < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :title, null: false
      t.text :description
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :location
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :events, :starts_at
    add_index :events, :ends_at
  end
end
