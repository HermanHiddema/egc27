class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.date :date_of_birth, null: false
      t.string :country, null: false
      t.string :city, null: false
      t.integer :playing_strength, null: false
      t.string :egd_pin

      t.timestamps
    end

    add_index :participants, :egd_pin
  end
end
