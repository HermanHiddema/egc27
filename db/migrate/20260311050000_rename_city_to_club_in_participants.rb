class RenameCityToClubInParticipants < ActiveRecord::Migration[8.1]
  def change
    rename_column :participants, :city, :club
  end
end
