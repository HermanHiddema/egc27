class AddConfirmationTokenToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :confirmation_token, :string
    add_index :participants, :confirmation_token, unique: true
  end
end
