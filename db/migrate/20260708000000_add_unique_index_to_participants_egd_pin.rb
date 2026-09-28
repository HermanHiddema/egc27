class AddUniqueIndexToParticipantsEgdPin < ActiveRecord::Migration[8.1]
  class MigrationParticipant < ActiveRecord::Base
    self.table_name = "participants"
  end

  def up
    deduplicate_egd_pins!
    remove_index :participants, :egd_pin
    add_index :participants, :egd_pin, unique: true
  end

  def down
    remove_index :participants, :egd_pin
    add_index :participants, :egd_pin
  end

  private

  def deduplicate_egd_pins!
    duplicate_pins.each do |pin|
      # Retain the latest registration for each PIN and clear earlier duplicates
      # so the unique index can be applied without dropping the affected rows.
      MigrationParticipant.where(egd_pin: pin).order(created_at: :desc, id: :desc).offset(1).update_all(egd_pin: nil)
    end
  end

  def duplicate_pins
    MigrationParticipant.where.not(egd_pin: [nil, ""]).group(:egd_pin).having("COUNT(*) > 1").pluck(:egd_pin)
  end
end
