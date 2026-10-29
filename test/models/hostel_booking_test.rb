require "test_helper"
require "ostruct"

# == Schema Information
#
# Table name: hostel_bookings
#
#  id                          :bigint           not null, primary key
#  amount_cents                :integer          not null
#  arrival_date                :date             not null
#  breakfast_price_cents       :integer          not null
#  breakfasts                  :integer          default(0), not null
#  departure_date              :date             not null
#  double_room_price_cents     :integer          not null
#  double_rooms                :integer          default(0), not null
#  female_dorm_bed_price_cents :integer          not null
#  female_dorm_beds            :integer          default(0), not null
#  mixed_dorm_bed_price_cents  :integer          not null
#  mixed_dorm_beds             :integer          default(0), not null
#  priced_on                   :date             not null
#  single_room_price_cents     :integer          not null
#  single_rooms                :integer          default(0), not null
#  six_person_room_price_cents :integer          not null
#  six_person_rooms            :integer          default(0), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  user_id                     :bigint           not null
#
# Indexes
#
#  index_hostel_bookings_on_user_id  (user_id)
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

  test "fixes the amount to the pricing period when the booking is made" do
    booking = build_booking

    travel_to Time.zone.local(2027, 3, 1) do
      booking.save!
      payment = Payment.build_for_hostel_booking(booking)

      assert_equal 3 * (8_200 + 2 * 985), payment.amount_cents
      assert_equal Date.new(2027, 3, 1), booking.priced_on
      assert_equal 8_200, booking.double_room_price_cents
      assert_equal 985, booking.breakfast_price_cents
      assert_equal payment.amount_cents, booking.amount_cents
    end

    assert_equal 3, booking.nights
    assert_equal 2, booking.beds
    assert_equal "unpaid", booking.status
    assert_equal 3 * (8_200 + 2 * 985), booking.price_lines.sum(&:subtotal_cents)
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

  test "a payment status update does not change the payment amount" do
    booking = build_booking
    travel_to Time.zone.local(2027, 1, 31) do
      booking.save!
    end

    payment = Payment.build_for_hostel_booking(booking).tap(&:save!)
    amount = payment.amount_cents

    travel_to Time.zone.local(2027, 2, 1) do
      payment.sync_from_mollie!(OpenStruct.new(id: "tr_hostel", status: "pending"))
    end

    assert_equal "pending", booking.reload.status
    assert_equal amount, payment.reload.amount_cents
  end

  test "a later payment uses the pricing period when the booking was made" do
    booking = nil
    travel_to Time.zone.local(2027, 1, 31) do
      booking = build_booking.tap(&:save!)
    end

    travel_to Time.zone.local(2027, 2, 1) do
      payment = Payment.build_for_hostel_booking(booking)

      assert_equal 3 * (7_900 + 2 * 985), payment.amount_cents
      assert_equal 3 * (7_900 + 2 * 985), booking.amount_cents
      assert_equal Date.new(2027, 1, 31), booking.priced_on
      assert_equal 7_900, booking.price_lines.first.unit_price_cents
    end
  end

  test "retains the booking-time price if current room prices change" do
    booking = nil
    travel_to Time.zone.local(2027, 1, 31) do
      booking = build_booking.tap(&:save!)
    end
    room_prices = HostelPricing::ROOM_TYPES.fetch("double_rooms").fetch(:prices)
    original_price = room_prices.fetch(:early)
    room_prices[:early] = original_price + 1

    assert_equal 3 * (7_900 + 2 * 985), booking.reload.amount_cents
    assert_equal 7_900, booking.price_lines.first.unit_price_cents
  ensure
    room_prices[:early] = original_price if room_prices && original_price
  end

  test "sends a confirmation email once when the booking becomes paid" do
    booking = build_booking.tap(&:save!)
    payment = Payment.build_for_hostel_booking(booking).tap(&:save!)

    assert_emails 1 do
      payment.sync_from_mollie!(OpenStruct.new(id: "tr_hostel", status: "paid", attributes: { "method" => "ideal" }))
      payment.update!(updated_at: Time.current)
    end

    assert payment.reload.confirmation_sent
    assert_equal "ideal", payment.payment_method
  end

  test "records refunds reported by Mollie" do
    booking = build_booking.tap(&:save!)
    payment = Payment.build_for_hostel_booking(booking).tap(&:save!)

    payment.sync_from_mollie!(OpenStruct.new(status: "paid", amount_refunded: OpenStruct.new(value: "10.00")))

    assert_equal "refunded", booking.reload.status
    assert_not booking.payable?
  end

  test "prevents destroying a booking with financial history or an active checkout" do
    booking = build_booking.tap(&:save!)
    Payment.build_for_hostel_booking(booking).tap do |payment|
      payment.mollie_payment_id = "tr_active_checkout"
      payment.save!
    end

    assert_raises(ActiveRecord::RecordNotDestroyed) { booking.destroy! }
    assert HostelBooking.exists?(booking.id)
  end
end
