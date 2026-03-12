class AddAttendancePeriodsToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :first_week, :boolean, null: false, default: true
    add_column :participants, :weekend, :boolean, null: false, default: true
    add_column :participants, :second_week, :boolean, null: false, default: true
  end
end
