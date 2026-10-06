class AddUniqueIndexToParticipantsEgdPin < ActiveRecord::Migration[8.1]
  class MigrationParticipant < ActiveRecord::Base
    self.table_name = "participants"
  end

  def up
    lock_participant_writes!
    normalize_blank_egd_pins!
    deduplicate_egd_pins!
    remove_index :participants, :egd_pin
    add_index :participants, :egd_pin, unique: true
  end

  def down
    remove_index :participants, :egd_pin
    add_index :participants, :egd_pin
  end

  private

  def lock_participant_writes!
    quoted_table_name = MigrationParticipant.connection.quote_table_name(MigrationParticipant.table_name)
    MigrationParticipant.connection.execute("LOCK TABLE #{quoted_table_name} IN SHARE ROW EXCLUSIVE MODE")
  end

  def deduplicate_egd_pins!
    duplicate_pins.each do |pin|
      # Retain the earliest registration for each PIN and clear later duplicates
      # so the unique index can be applied without dropping the affected rows.
      MigrationParticipant.where(egd_pin: pin).order(created_at: :asc, id: :asc).offset(1).update_all(egd_pin: nil)
    end
  end

  def normalize_blank_egd_pins!
    MigrationParticipant.where(egd_pin: "").update_all(egd_pin: nil)
  end

  def duplicate_pins
    MigrationParticipant.where.not(egd_pin: [nil, ""]).group(:egd_pin).having("COUNT(*) > 1").pluck(:egd_pin)
  end
end
