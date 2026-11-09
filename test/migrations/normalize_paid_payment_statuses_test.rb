require "test_helper"
require Rails.root.join("db/migrate/20261109110000_normalize_paid_payment_statuses").to_s

class NormalizePaidPaymentStatusesTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @previous_path = @connection.schema_search_path
    @schema = "payment_status_migration_#{Process.pid}_#{object_id}"
    @connection.execute("CREATE SCHEMA #{@schema}")
    @connection.schema_search_path = @schema
    @connection.create_table(:payments) do |t|
      t.string :status
      t.integer :amount_cents
    end
    @connection.create_table(:refunds) do |t|
      t.integer :payment_id
      t.integer :amount_cents
    end
    @connection.create_table(:chargebacks) do |t|
      t.integer :payment_id
      t.integer :amount_cents
      t.datetime :reversed_at
    end
  end

  teardown do
    @connection.schema_search_path = @previous_path
    @connection.schema_cache.clear!
    @connection.execute("DROP SCHEMA #{@schema} CASCADE")
  end

  test "preserves amounts and reversal information while restoring paid statuses" do
    @connection.execute(<<~SQL)
      INSERT INTO payments (id, status, amount_cents) VALUES
        (1, 'refunded', 5000), (2, 'charged_back', 8000),
        (3, 'refunded', 9000), (4, 'paid', 10000), (5, 'failed', 7000)
    SQL
    @connection.execute("INSERT INTO refunds (payment_id, amount_cents) VALUES (1, 1200), (1, 300), (4, 2000)")
    @connection.execute("INSERT INTO chargebacks (payment_id, amount_cents) VALUES (2, 4000)")

    migration = NormalizePaidPaymentStatuses.new
    migration.migrate(:up)

    assert_equal [
      [1, "paid", 5000, 1500, 0],
      [2, "paid", 8000, 0, 4000],
      [3, "paid", 9000, nil, 0],
      [4, "paid", 10000, 2000, 0],
      [5, "failed", 7000, 0, 0]
    ], @connection.select_rows("SELECT id, status, amount_cents, amount_refunded_cents, amount_charged_back_cents FROM payments ORDER BY id")
    assert_raises(ActiveRecord::IrreversibleMigration) { migration.migrate(:down) }
  end
end
