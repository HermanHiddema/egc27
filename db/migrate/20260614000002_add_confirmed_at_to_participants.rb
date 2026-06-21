class AddConfirmedAtToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :confirmed_at, :datetime
    add_index :participants, :confirmed_at
  end
end
