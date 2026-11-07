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
      t.timestamps null: false
      t.check_constraint "(participant_id IS NULL) <> (hostel_booking_id IS NULL)", name: "payments_have_one_payee"
    end
    @connection.execute("INSERT INTO participants (id, first_week, weekend, second_week, created_at, updated_at) VALUES (1, FALSE, TRUE, FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
    @connection.execute("INSERT INTO hostel_bookings (id, created_at, updated_at) VALUES (2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
  end

  teardown do
    @connection.schema_search_path = @previous_path
    @connection.schema_cache.clear!
    [Payment, Participant, HostelBooking, Order, Product, ParticipantTicket].each(&:reset_column_information)
    @connection.execute("DROP SCHEMA #{@schema} CASCADE")
  end

  test "migrates tickets and multiple payment attempts without changing payment identifiers" do
    @connection.execute(<<~SQL)
      INSERT INTO payments (id, participant_id, hostel_booking_id, mollie_payment_id, amount_cents, created_at, updated_at)
      VALUES (10, 1, NULL, 'tr_first', 5000, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
             (11, 1, NULL, 'tr_retry', 5000, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
             (12, NULL, 2, 'tr_hostel', 8000, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    IntroduceOrdersAndParticipantTickets.new.up
    assert_equal [[1, false, true, false]], @connection.select_rows("SELECT participant_id, first_week, weekend, second_week FROM participant_tickets")
    rows = @connection.select_rows("SELECT id, mollie_payment_id, amount_cents, order_id FROM payments ORDER BY id")
    assert_equal [[10, "tr_first", 5000], [11, "tr_retry", 5000], [12, "tr_hostel", 8000]], rows.map { |row| row.first(3) }
    assert_equal rows[0][3], rows[1][3]
    assert_not_equal rows[0][3], rows[2][3]
    assert_equal [["HostelBooking", 2], ["ParticipantTicket", 1]], @connection.select_rows("SELECT productable_type, productable_id FROM products ORDER BY productable_type")
    @connection.execute("INSERT INTO participants (id, participant_type, created_at, updated_at) VALUES (2, 'visitor', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
    IntroduceOrdersAndParticipantTickets.new.down
    assert_equal [[1, false, true, false], [2, true, true, true]], @connection.select_rows("SELECT id, first_week, weekend, second_week FROM participants ORDER BY id")
    assert_equal [[10, 1, nil, "tr_first"], [11, 1, nil, "tr_retry"], [12, nil, 2, "tr_hostel"]],
      @connection.select_rows("SELECT id, participant_id, hostel_booking_id, mollie_payment_id FROM payments ORDER BY id")
  end

  test "reports payments without a matching payee" do
    @connection.remove_check_constraint :payments, name: "payments_have_one_payee"
    @connection.execute("INSERT INTO payments (id, amount_cents, created_at, updated_at) VALUES (99, 1000, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
    error = assert_raises(RuntimeError) { IntroduceOrdersAndParticipantTickets.new.up }
    assert_match(/99/, error.message)
    assert_equal 1, @connection.select_value("SELECT COUNT(*) FROM payments")
  end
end
