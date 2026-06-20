class AddIndexToParticipantsOnCreatedAt < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :participants, :created_at, algorithm: :concurrently
  end
end
