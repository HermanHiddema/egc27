class AddNotNullConstraintToParticipantsEmail < ActiveRecord::Migration[8.1]
  def change
    change_column_null :participants, :email, false
  end
end
