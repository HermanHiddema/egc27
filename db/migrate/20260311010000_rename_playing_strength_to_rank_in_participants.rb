class RenamePlayingStrengthToRankInParticipants < ActiveRecord::Migration[8.1]
  def change
    rename_column :participants, :playing_strength, :rank
    change_column_null :participants, :rank, true
  end
end
