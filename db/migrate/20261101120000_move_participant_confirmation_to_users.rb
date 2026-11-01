class MoveParticipantConfirmationToUsers < ActiveRecord::Migration[8.1]
  def up
    inconsistent = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM participants
      INNER JOIN users ON users.id = participants.user_id
      WHERE (participants.confirmed_at IS NULL) != (users.confirmed_at IS NULL)
    SQL
    if inconsistent.positive?
      raise ActiveRecord::MigrationError, "#{inconsistent} participants have confirmation status different from their user; reconcile these records before migrating"
    end

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
