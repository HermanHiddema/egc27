class AddPhoneToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :phone, :string
    add_index :participants, :phone
  end
end
