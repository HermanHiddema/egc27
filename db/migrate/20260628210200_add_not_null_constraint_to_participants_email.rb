class AddNotNullConstraintToParticipantsEmail < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE participants
      SET email = users.email
      FROM users
      WHERE participants.user_id = users.id
        AND participants.email IS NULL
    SQL

    remaining_nulls = select_value("SELECT COUNT(*) FROM participants WHERE email IS NULL").to_i
    if remaining_nulls.positive?
      raise ActiveRecord::MigrationError,
            "Cannot enforce NOT NULL on participants.email: #{remaining_nulls} rows still have NULL email"
    end

    change_column_null :participants, :email, false
  end

  def down
    change_column_null :participants, :email, true
  end
end
