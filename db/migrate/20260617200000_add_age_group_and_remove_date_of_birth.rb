class AddAgeGroupAndRemoveDateOfBirth < ActiveRecord::Migration[8.1]
  # Age on the first day of EGC 2027 (24 July 2027) determines the age group.
  # A person has had their birthday if their month/day is on or before 07/24.
  AGE_GROUP_SQL = <<~SQL.squish
    CASE
      WHEN (2027 - EXTRACT(YEAR FROM date_of_birth)::int -
            CASE WHEN EXTRACT(MONTH FROM date_of_birth) > 7
                   OR (EXTRACT(MONTH FROM date_of_birth) = 7
                       AND EXTRACT(DAY FROM date_of_birth) > 24)
                 THEN 1 ELSE 0 END) <= 11 THEN '0-11'
      WHEN (2027 - EXTRACT(YEAR FROM date_of_birth)::int -
            CASE WHEN EXTRACT(MONTH FROM date_of_birth) > 7
                   OR (EXTRACT(MONTH FROM date_of_birth) = 7
                       AND EXTRACT(DAY FROM date_of_birth) > 24)
                 THEN 1 ELSE 0 END) <= 17 THEN '12-17'
      WHEN (2027 - EXTRACT(YEAR FROM date_of_birth)::int -
            CASE WHEN EXTRACT(MONTH FROM date_of_birth) > 7
                   OR (EXTRACT(MONTH FROM date_of_birth) = 7
                       AND EXTRACT(DAY FROM date_of_birth) > 24)
                 THEN 1 ELSE 0 END) <= 49 THEN '18-49'
      ELSE '50+'
    END
  SQL

  def up
    add_column :participants, :age_group, :string

    execute("UPDATE participants SET age_group = #{AGE_GROUP_SQL} WHERE date_of_birth IS NOT NULL")

    change_column_null :participants, :age_group, false, "18-49"
    remove_column :participants, :date_of_birth
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Cannot restore date_of_birth values from age_group ranges. " \
      "This migration is intentionally irreversible to prevent data loss."
  end
end
