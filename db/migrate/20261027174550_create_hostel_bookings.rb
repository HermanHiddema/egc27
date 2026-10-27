class CreateHostelBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :hostel_bookings do |t|
      t.references :user, null: false, foreign_key: true
      t.date :arrival_date, null: false
      t.date :departure_date, null: false
      t.integer :single_rooms, null: false, default: 0
      t.integer :double_rooms, null: false, default: 0
      t.integer :six_person_rooms, null: false, default: 0
      t.integer :mixed_dorm_beds, null: false, default: 0
      t.integer :female_dorm_beds, null: false, default: 0
      t.integer :breakfasts, null: false, default: 0
      t.integer :amount_cents, null: false
      t.date :priced_on, null: false
      t.string :status, null: false, default: "open"
      t.string :mollie_payment_id
      t.string :payment_method
      t.boolean :confirmation_sent, null: false, default: false

      t.timestamps
    end
    add_index :hostel_bookings, :mollie_payment_id, unique: true
    add_index :hostel_bookings, :status
  end
end
