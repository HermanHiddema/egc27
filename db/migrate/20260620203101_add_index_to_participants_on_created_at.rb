class AddIndexToParticipantsOnCreatedAt < ActiveRecord::Migration[8.1]
  def change
    add_index :participants, :created_at
  end
end
