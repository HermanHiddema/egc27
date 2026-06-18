class RemoveUserIdFromCalendarEvents < ActiveRecord::Migration[8.1]
  def change
    # CalendarEvents are schedule entries owned by the organisation, not by individual users.
    # The user_id column is intentionally removed as the CalendarEvent model no longer
    # has a belongs_to :user association.
    remove_column :calendar_events, :user_id, :bigint
  end
end
