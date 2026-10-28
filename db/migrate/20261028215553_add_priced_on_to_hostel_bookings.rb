class AddPricedOnToHostelBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :hostel_bookings, :priced_on, :date, null: false
  end
end
