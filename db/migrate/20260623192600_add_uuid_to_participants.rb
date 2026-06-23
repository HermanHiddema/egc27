class AddUuidToParticipants < ActiveRecord::Migration[8.1]
  def change
    # gen_random_uuid() is available in PostgreSQL core (13+) but pgcrypto
    # provides it on older versions, so ensure it is enabled.
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    # Adding the column with a volatile default backfills every existing row
    # with a distinct random (v4) UUID and defaults new rows the same way.
    add_column :participants, :uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false
    add_index :participants, :uuid, unique: true
  end
end
