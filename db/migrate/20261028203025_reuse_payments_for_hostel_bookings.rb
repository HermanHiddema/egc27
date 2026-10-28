class ReusePaymentsForHostelBookings < ActiveRecord::Migration[8.1]
  def up
    add_reference :payments, :hostel_booking, foreign_key: true
    change_column_null :payments, :participant_id, true

    execute <<~SQL
      INSERT INTO payments (
        amount_cents, confirmation_sent, created_at, description, mollie_payment_id,
        participant_id, hostel_booking_id, payment_method, processed_in_bookkeeping,
        provider, reference, status, updated_at, payment_date
      )
      SELECT
        hostel_bookings.amount_cents,
        hostel_bookings.confirmation_sent,
        hostel_bookings.priced_on,
        'EGC 2027 Hostel booking ' || hostel_bookings.id,
        hostel_bookings.mollie_payment_id,
        NULL,
        hostel_bookings.id,
        hostel_bookings.payment_method,
        FALSE,
        'mollie',
        NULL,
        hostel_bookings.status,
        hostel_bookings.updated_at,
        CASE
          WHEN hostel_bookings.status IN ('paid', 'refunded', 'charged_back') THEN hostel_bookings.priced_on
          ELSE NULL
        END
      FROM hostel_bookings
      WHERE hostel_bookings.mollie_payment_id IS NOT NULL
        OR hostel_bookings.status != 'open'
        OR hostel_bookings.payment_method IS NOT NULL
        OR hostel_bookings.confirmation_sent = TRUE
    SQL

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
