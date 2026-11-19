class AddAdminStatusToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :admin_status, :string
  end
end
