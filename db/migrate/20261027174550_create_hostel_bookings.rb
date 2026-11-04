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
      t.date :priced_on, null: false
      t.timestamps

      t.integer :single_room_price_cents, null: false
      t.integer :double_room_price_cents, null: false
      t.integer :six_person_room_price_cents, null: false
      t.integer :mixed_dorm_bed_price_cents, null: false
      t.integer :female_dorm_bed_price_cents, null: false
      t.integer :breakfast_price_cents, null: false
      t.integer :amount_cents, null: false
    end
  end
end
