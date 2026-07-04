class AddNotNullConstraintToParticipantsEmail < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE participants
      SET email = users.email
      FROM users
      WHERE participants.user_id = users.id
        AND participants.email IS NULL
    SQL

    change_column_null :participants, :email, false
  end

  def down
    change_column_null :participants, :email, true
  end
end
