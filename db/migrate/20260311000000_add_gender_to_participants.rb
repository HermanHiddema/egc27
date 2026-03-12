class AddGenderToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :gender, :string
    add_index :participants, :gender
  end
end
