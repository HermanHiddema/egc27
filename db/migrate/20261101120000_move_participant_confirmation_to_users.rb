class MoveParticipantConfirmationToUsers < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE users SET confirmed_at = confirmations.confirmed_at
      FROM (
        SELECT user_id, MIN(confirmed_at) AS confirmed_at
        FROM participants
        WHERE confirmed_at IS NOT NULL
        GROUP BY user_id
      ) AS confirmations
      WHERE users.id = confirmations.user_id AND users.confirmed_at IS NULL
    SQL

    remove_column :participants, :confirmation_token, :string
    remove_column :participants, :confirmed_at, :datetime
  end

  def down
    add_column :participants, :confirmed_at, :datetime
    add_column :participants, :confirmation_token, :string
    add_index :participants, :confirmed_at
    add_index :participants, :confirmation_token, unique: true
    execute <<~SQL
      UPDATE participants SET confirmed_at = users.confirmed_at
      FROM users WHERE users.id = participants.user_id
    SQL
  end
end
