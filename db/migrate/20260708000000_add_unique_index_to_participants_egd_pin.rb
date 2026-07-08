class AddUniqueIndexToParticipantsEgdPin < ActiveRecord::Migration[8.1]
  def change
    remove_index :participants, :egd_pin
    add_index :participants, :egd_pin, unique: true
  end
end
