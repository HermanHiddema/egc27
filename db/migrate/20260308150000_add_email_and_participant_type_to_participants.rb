class AddEmailAndParticipantTypeToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :email, :string
    add_column :participants, :participant_type, :string, null: false, default: "player"

    add_index :participants, :email
    add_index :participants, :participant_type
  end
end
