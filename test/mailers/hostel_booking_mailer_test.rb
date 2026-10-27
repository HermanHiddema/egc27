require "test_helper"

class HostelBookingMailerTest < ActionMailer::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "payment confirmation lists the price calculation per item" do
    booking = users(:one).hostel_bookings.build(
      arrival_date: Date.new(2027, 7, 24),
      departure_date: Date.new(2027, 7, 27),
      single_rooms: 1,
      breakfasts: 1
    )
    travel_to Time.zone.local(2027, 3, 1) do
      booking.save!
    end

    email = HostelBookingMailer.payment_confirmation(booking)

    assert_equal [users(:one).email], email.to
    assert_equal "EGC 2027 – Hostel booking paid", email.subject
    body = email.body.encoded
    assert_match "1 × 1-person room × 3 nights × € 72.00 = € 216.00", body
    assert_match "1 × Breakfast buffet × 3 nights × € 9.85 = € 29.55", body
    assert_match "€ 245.55", body
  end
end
