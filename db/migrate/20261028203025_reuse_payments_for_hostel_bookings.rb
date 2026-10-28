class ReusePaymentsForHostelBookings < ActiveRecord::Migration[8.1]
  def up
    add_reference :payments, :hostel_booking, foreign_key: true
    change_column_null :payments, :participant_id, true

    add_check_constraint :payments,
      "(participant_id IS NULL) <> (hostel_booking_id IS NULL)",
      name: "payments_have_one_payee"

    remove_index :hostel_bookings, :mollie_payment_id
    remove_index :hostel_bookings, :status
    remove_column :hostel_bookings, :amount_cents
    remove_column :hostel_bookings, :priced_on
    remove_column :hostel_bookings, :status
    remove_column :hostel_bookings, :mollie_payment_id
    remove_column :hostel_bookings, :payment_method
    remove_column :hostel_bookings, :confirmation_sent
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Hostel payments are stored as independent payment attempts."
  end
end
