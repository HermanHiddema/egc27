require "test_helper"
require Rails.root.join("db/migrate/20261106120000_introduce_orders_and_participant_tickets")

class OrdersMigrationTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @previous_path = @connection.schema_search_path
    @schema = "orders_migration_#{Process.pid}_#{object_id}"
    @connection.execute("CREATE SCHEMA #{@schema}")
    @connection.schema_search_path = @schema
    @connection.create_table(:participants) do |t|
      t.string :participant_type, null: false, default: "player"
      t.string :age_group, null: false
      t.boolean :first_week, null: false
      t.boolean :weekend, null: false
      t.boolean :second_week, null: false
      t.timestamps null: false
    end
    @connection.create_table(:hostel_bookings) { |t| t.timestamps null: false }
    @connection.create_table(:payments) do |t|
      t.references :participant, foreign_key: true
      t.references :hostel_booking, foreign_key: true
      t.string :mollie_payment_id
      t.integer :amount_cents
      t.string :status
      t.timestamps null: false
      t.check_constraint "(participant_id IS NULL) <> (hostel_booking_id IS NULL)", name: "payments_have_one_payee"
    end
    @connection.execute(<<~SQL)
      INSERT INTO participants (id, participant_type, age_group, first_week, weekend, second_week, created_at, updated_at)
      VALUES (1, 'player', '18-49', false, true, false, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
             (2, 'player', '12-17', false, true, false, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
             (3, 'visitor', '50+', true, true, false, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
             (4, 'visitor', '18-49', true, true, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
             (5, 'player', '18-49', true, true, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    @connection.execute("INSERT INTO hostel_bookings (id, created_at, updated_at) VALUES (2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
  end

  teardown do
    @connection.schema_search_path = @previous_path
    @connection.schema_cache.clear!
    [Payment, Participant, HostelBooking, Order, Product, ParticipantTicket].each(&:reset_column_information)
    @connection.execute("DROP SCHEMA #{@schema} CASCADE")
  end

  test "preserves attendance and prices while linking historical payments to orders" do
    @connection.execute(<<~SQL)
      INSERT INTO payments (id, participant_id, hostel_booking_id, mollie_payment_id, amount_cents, status, created_at, updated_at)
      VALUES (10, 1, NULL, 'tr_first', 5000, 'paid', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
             (11, 1, NULL, 'tr_retry', 9000, 'pending', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
             (12, NULL, 2, 'tr_hostel', 8000, 'paid', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
             (13, 4, NULL, 'tr_visitor', 7000, 'paid', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
             (14, 5, NULL, 'tr_refund', 12000, 'refunded', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    before_attendance = @connection.select_rows("SELECT id, first_week, weekend, second_week FROM participants ORDER BY id")
    travel_to Date.new(2026, 9, 1) do
      IntroduceOrdersAndParticipantTickets.new.up
    end

    assert_equal before_attendance, @connection.select_rows("SELECT id, first_week, weekend, second_week FROM participants ORDER BY id")
    assert_equal [[1, 5000], [2, 3000], [4, 7000], [5, 12000]],
      @connection.select_rows("SELECT participant_id, price_cents FROM participant_tickets ORDER BY participant_id")
    assert_equal 0, @connection.select_value("SELECT COUNT(*) FROM participant_tickets WHERE participant_id = 3")
    rows = @connection.select_rows("SELECT id, mollie_payment_id, amount_cents, order_id FROM payments ORDER BY id")
    assert_equal [[10, "tr_first", 5000], [11, "tr_retry", 9000], [12, "tr_hostel", 8000], [13, "tr_visitor", 7000], [14, "tr_refund", 12000]], rows.map { |row| row.first(3) }
    assert_equal rows[0][3], rows[1][3]
    assert_not_equal rows[0][3], rows[2][3]
    assert_equal [["HostelBooking", 2]], @connection.select_rows("SELECT productable_type, productable_id FROM products WHERE productable_type = 'HostelBooking'")

    error = assert_raises(ActiveRecord::IrreversibleMigration) { IntroduceOrdersAndParticipantTickets.new.down }
    assert_match(/Ticket prices would be lost/, error.message)
    @connection.execute("UPDATE participant_tickets SET price_cents = NULL")
    IntroduceOrdersAndParticipantTickets.new.down
    assert_equal before_attendance, @connection.select_rows("SELECT id, first_week, weekend, second_week FROM participants ORDER BY id")
    assert_equal [[10, 1, nil, "tr_first"], [11, 1, nil, "tr_retry"], [12, nil, 2, "tr_hostel"], [13, 4, nil, "tr_visitor"], [14, 5, nil, "tr_refund"]],
      @connection.select_rows("SELECT id, participant_id, hostel_booking_id, mollie_payment_id FROM payments ORDER BY id")
  end

  test "reports payments without a matching payee" do
    @connection.remove_check_constraint :payments, name: "payments_have_one_payee"
    @connection.execute("INSERT INTO payments (id, amount_cents, created_at, updated_at) VALUES (99, 1000, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
    error = assert_raises(RuntimeError) { IntroduceOrdersAndParticipantTickets.new.up }
    assert_match(/99/, error.message)
    assert_equal 1, @connection.select_value("SELECT COUNT(*) FROM payments")
  end

  test "reports prices that cannot be derived without changing attendance" do
    @connection.execute("UPDATE participants SET age_group = 'unknown' WHERE id = 2")
    output, = capture_io { IntroduceOrdersAndParticipantTickets.new.up }
    assert_match(/Ticket prices could not be calculated for ticket IDs:/, output)
    assert_nil @connection.select_value("SELECT price_cents FROM participant_tickets WHERE participant_id = 2")
    assert_equal [false, true, false], @connection.select_rows("SELECT first_week, weekend, second_week FROM participants WHERE id = 2").first
  end

  test "rollback refuses to turn unknown attendance into assumed values" do
    IntroduceOrdersAndParticipantTickets.new.up
    @connection.execute("UPDATE participant_tickets SET price_cents = NULL")
    @connection.execute("UPDATE participants SET first_week = NULL WHERE id = 3")
    error = assert_raises(ActiveRecord::IrreversibleMigration) { IntroduceOrdersAndParticipantTickets.new.down }
    assert_match(/Attendance is unknown.*3/, error.message)
  end
end
