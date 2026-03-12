class AddRatingToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :rating, :integer
    add_index :participants, :rating
  end
end
