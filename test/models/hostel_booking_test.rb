require "test_helper"
require "ostruct"

# == Schema Information
#
# Table name: hostel_bookings
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer          not null
#  arrival_date      :date             not null
#  breakfasts        :integer          default(0), not null
#  confirmation_sent :boolean          default(FALSE), not null
#  departure_date    :date             not null
#  double_rooms      :integer          default(0), not null
#  female_dorm_beds  :integer          default(0), not null
#  mixed_dorm_beds   :integer          default(0), not null
#  payment_method    :string
#  priced_on         :date             not null
#  single_rooms      :integer          default(0), not null
#  six_person_rooms  :integer          default(0), not null
#  status            :string           default("open"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  mollie_payment_id :string
#  user_id           :bigint           not null
#
# Indexes
#
#  index_hostel_bookings_on_mollie_payment_id  (mollie_payment_id) UNIQUE
#  index_hostel_bookings_on_status             (status)
#  index_hostel_bookings_on_user_id            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class HostelBookingTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  def build_booking(**attributes)
    users(:one).hostel_bookings.build({
      arrival_date: Date.new(2027, 7, 24),
      departure_date: Date.new(2027, 7, 27),
      double_rooms: 1,
      breakfasts: 2
    }.merge(attributes))
  end

  test "calculates the amount for the current pricing period on create" do
    booking = build_booking

    travel_to Time.zone.local(2027, 3, 1) do
      booking.save!
    end

    assert_equal 3, booking.nights
    assert_equal 2, booking.beds
    assert_equal 3 * (8_200 + 2 * 985), booking.amount_cents
    assert_equal Date.new(2027, 3, 1), booking.priced_on
    assert_equal "open", booking.status
  end

  test "arrival can not be before 24 July 2027" do
    booking = build_booking(arrival_date: Date.new(2027, 7, 23))

    assert_not booking.valid?
    assert_includes booking.errors[:arrival_date], "can not be before 24 July 2027"
  end

  test "departure can not be after 7 August 2027" do
    booking = build_booking(departure_date: Date.new(2027, 8, 8))

    assert_not booking.valid?
    assert_includes booking.errors[:departure_date], "can not be after 7 August 2027"
  end

  test "departure must be after arrival" do
    booking = build_booking(arrival_date: Date.new(2027, 7, 30), departure_date: Date.new(2027, 7, 30))

    assert_not booking.valid?
    assert_includes booking.errors[:departure_date], "must be after the arrival date"
  end

  test "requires at least one room or bed" do
    booking = build_booking(double_rooms: 0, breakfasts: 0)

    assert_not booking.valid?
    assert_includes booking.errors[:base], "Please book at least one room or bed"
  end

  test "breakfasts can not exceed the number of beds" do
    booking = build_booking(breakfasts: 3)

    assert_not booking.valid?
    assert_includes booking.errors[:breakfasts], "can not be more than the number of beds (2)"
  end

  test "quantities can not be negative" do
    booking = build_booking(single_rooms: -1)

    assert_not booking.valid?
    assert booking.errors[:single_rooms].any?
  end

  test "a status update does not change the amount" do
    booking = build_booking
    travel_to Time.zone.local(2027, 1, 31) do
      booking.save!
    end
    amount = booking.amount_cents

    travel_to Time.zone.local(2027, 2, 1) do
      booking.sync_from_mollie!(OpenStruct.new(id: "tr_hostel", status: "pending"))
    end

    assert_equal "pending", booking.reload.status
    assert_equal amount, booking.amount_cents
  end

  test "sends a confirmation email once when the booking becomes paid" do
    booking = build_booking.tap(&:save!)

    assert_emails 1 do
      booking.sync_from_mollie!(OpenStruct.new(id: "tr_hostel", status: "paid", attributes: { "method" => "ideal" }))
      booking.update!(updated_at: Time.current)
    end

    assert booking.reload.confirmation_sent
    assert_equal "ideal", booking.payment_method
  end

  test "records refunds reported by Mollie" do
    booking = build_booking.tap(&:save!)

    booking.sync_from_mollie!(OpenStruct.new(status: "paid", amount_refunded: OpenStruct.new(value: "10.00")))

    assert_equal "refunded", booking.status
    assert_not booking.payable?
  end
end
