class AddPriceSnapshotToHostelBookings < ActiveRecord::Migration[8.1]
  class ExistingBooking < ActiveRecord::Base
    self.table_name = "hostel_bookings"
  end

  ROOM_PRICE_COLUMNS = {
    "single_rooms" => :single_room_price_cents,
    "double_rooms" => :double_room_price_cents,
    "six_person_rooms" => :six_person_room_price_cents,
    "mixed_dorm_beds" => :mixed_dorm_bed_price_cents,
    "female_dorm_beds" => :female_dorm_bed_price_cents
  }.freeze
  BREAKFAST_PRICE_CENTS = 985
  PRICE_PERIODS = [
    [Date.new(2027, 1, 31), {
      single_room_price_cents: 6_900, double_room_price_cents: 7_900, six_person_room_price_cents: 16_500,
      mixed_dorm_bed_price_cents: 2_900, female_dorm_bed_price_cents: 2_900
    }.freeze],
    [Date.new(2027, 5, 31), {
      single_room_price_cents: 7_200, double_room_price_cents: 8_200, six_person_room_price_cents: 18_000,
      mixed_dorm_bed_price_cents: 3_200, female_dorm_bed_price_cents: 3_200
    }.freeze],
    [nil, {
      single_room_price_cents: 7_500, double_room_price_cents: 8_500, six_person_room_price_cents: 19_500,
      mixed_dorm_bed_price_cents: 3_500, female_dorm_bed_price_cents: 3_500
    }.freeze]
  ].freeze
  PRICE_COLUMNS = (ROOM_PRICE_COLUMNS.values + [:breakfast_price_cents, :amount_cents]).freeze

  def up
    ROOM_PRICE_COLUMNS.each_value { |column| add_column :hostel_bookings, column, :integer }
    add_column :hostel_bookings, :breakfast_price_cents, :integer
    add_column :hostel_bookings, :amount_cents, :integer

    ExistingBooking.reset_column_information
    ExistingBooking.find_each do |booking|
      prices = PRICE_PERIODS.find { |last_date, _| last_date.nil? || booking.priced_on <= last_date }.last
      amount = ROOM_PRICE_COLUMNS.sum { |room_type, price_column| booking[room_type] * prices.fetch(price_column) }
      amount = (amount + booking.breakfasts * BREAKFAST_PRICE_CENTS) * (booking.departure_date - booking.arrival_date).to_i
      booking.update_columns(prices.merge(breakfast_price_cents: BREAKFAST_PRICE_CENTS, amount_cents: amount))
    end

    PRICE_COLUMNS.each { |column| change_column_null :hostel_bookings, column, false }
  end

  def down
    remove_columns :hostel_bookings, *PRICE_COLUMNS
  end
end
