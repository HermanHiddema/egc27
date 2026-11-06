require "test_helper"
require Rails.root.join("db/migrate/20261106130000_move_attendance_to_participants_and_price_tickets")

class AttendancePriceMigrationTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @previous_path = @connection.schema_search_path
    @schema = "attendance_migration_#{Process.pid}_#{object_id}"
    @connection.execute("CREATE SCHEMA #{@schema}")
    @connection.schema_search_path = @schema
    @connection.create_table(:participants) { |t| t.string :age_group }
    @connection.create_table(:participant_tickets) do |t|
      t.bigint :participant_id
      t.boolean :first_week, null: false
      t.boolean :weekend, null: false
      t.boolean :second_week, null: false
    end
    @connection.create_table(:products) do |t|
      t.bigint :order_id
      t.string :productable_type
      t.bigint :productable_id
    end
    @connection.create_table(:payments) do |t|
      t.bigint :order_id
      t.integer :amount_cents
      t.string :status
      t.string :mollie_payment_id
      t.timestamps null: false
    end
    @connection.execute("INSERT INTO participants (id, age_group) VALUES (1, '18-49'), (2, '12-17'), (3, '50+'), (4, '18-49')")
    @connection.execute("INSERT INTO participant_tickets (id, participant_id, first_week, weekend, second_week) VALUES (11, 1, true, true, true), (12, 2, false, true, false), (13, 4, true, true, true)")
    @connection.execute("INSERT INTO products (order_id, productable_type, productable_id) VALUES (21, 'ParticipantTicket', 11), (22, 'ParticipantTicket', 12), (23, 'ParticipantTicket', 13)")
    @connection.execute("INSERT INTO payments (id, order_id, amount_cents, status, mollie_payment_id, created_at, updated_at) VALUES (31, 21, 19000, 'paid', 'tr_history', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), (32, 21, 25000, 'pending', 'tr_pending', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), (33, 23, 12000, 'refunded', 'tr_refunded', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
  end

  teardown do
    @connection.schema_search_path = @previous_path
    @connection.schema_cache.clear!
    [Payment, Participant, ParticipantTicket, Product, Order].each(&:reset_column_information)
    @connection.execute("DROP SCHEMA #{@schema} CASCADE")
  end

  test "preserves attendance and payment prices while keeping ticket-free attendance unknown" do
    travel_to Date.new(2026, 9, 1) do
      MoveAttendanceToParticipantsAndPriceTickets.new.up
    end
    assert_equal [[1, true, true, true], [2, false, true, false], [3, nil, nil, nil], [4, true, true, true]],
      @connection.select_rows("SELECT id, first_week, weekend, second_week FROM participants ORDER BY id")
    assert_equal [[11, 19000], [12, 3000], [13, 12000]], @connection.select_rows("SELECT id, price_cents FROM participant_tickets ORDER BY id")
    assert_equal [[31, 19000, "tr_history"], [32, 25000, "tr_pending"], [33, 12000, "tr_refunded"]], @connection.select_rows("SELECT id, amount_cents, mollie_payment_id FROM payments ORDER BY id")

    error = assert_raises(ActiveRecord::IrreversibleMigration) { MoveAttendanceToParticipantsAndPriceTickets.new.down }
    assert_match(/Ticket prices would be lost/, error.message)
    @connection.execute("UPDATE participant_tickets SET price_cents = NULL")
    MoveAttendanceToParticipantsAndPriceTickets.new.down
    assert_equal [[11, true, true, true], [12, false, true, false], [13, true, true, true]],
      @connection.select_rows("SELECT id, first_week, weekend, second_week FROM participant_tickets ORDER BY id")
  end

  test "rollback refuses to discard attendance for a participant without a ticket" do
    MoveAttendanceToParticipantsAndPriceTickets.new.up
    @connection.execute("UPDATE participants SET first_week = true, weekend = true, second_week = false WHERE id = 3")
    error = assert_raises(ActiveRecord::IrreversibleMigration) { MoveAttendanceToParticipantsAndPriceTickets.new.down }
    assert_match(/3/, error.message)
  end
end
