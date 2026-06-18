class MakeCalendarEventColorOptionalOverride < ActiveRecord::Migration[8.1]
  def change
    change_column_default :calendar_events, :color, from: "#dbeafe", to: nil
    change_column_null :calendar_events, :color, true
  end
end
