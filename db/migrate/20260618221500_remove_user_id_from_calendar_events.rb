class RemoveUserIdFromCalendarEvents < ActiveRecord::Migration[8.1]
  def change
    remove_column :calendar_events, :user_id, :bigint
  end
end
