require "test_helper"

class Admin::HostelBookingsControllerTest < ActionDispatch::IntegrationTest
  test "admin sees all hostel bookings" do
    booking = users(:one).hostel_bookings.create!(
      arrival_date: Date.new(2027, 7, 24),
      departure_date: Date.new(2027, 7, 26),
      female_dorm_beds: 1
    )
    sign_in users(:admin)

    get admin_hostel_bookings_path

    assert_response :success
    assert_match users(:one).email, response.body
    assert_select "td", text: booking.amount_formatted
    assert_select "select[name='order_status'] option[value='active']"
    assert_select "input[name='order_status[]']", count: 0

    get admin_hostel_booking_path(booking)
    assert_response :success
    assert_select "p", text: /1 × 1 bed in a 6-person dorm/, count: 0
    assert_select "td", text: /female dorm bed/
  end

  test "non-admin can not see hostel bookings" do
    sign_in users(:one)

    get admin_hostel_bookings_path

    assert_redirected_to root_path
  end
end

class Admin::HostelBookingsControllerTest
  test "combined filters use effective payment status and order cancellation independently" do
    paid = users(:one).hostel_bookings.create!(arrival_date: Date.new(2027, 7, 24), departure_date: Date.new(2027, 7, 26), single_rooms: 1)
    paid.order.submit!
    paid.order.payments.create!(amount_cents: paid.amount_cents, description: paid.description, status: "paid")
    canceled = users(:two).hostel_bookings.create!(arrival_date: Date.new(2027, 7, 24), departure_date: Date.new(2027, 7, 26), single_rooms: 1)
    canceled.order.submit!
    canceled.order.cancel!
    sign_in users(:admin)

    get admin_hostel_bookings_path, params: { payment_status: ["paid"], order_status: "active", sort: "id", direction: "asc", page: "2" }
    assert_response :success
    assert_select "a[href*=?]", "/admin/hostel_bookings/#{paid.id}", minimum: 1
    assert_select "a[href*=?]", "/admin/hostel_bookings/#{canceled.id}", count: 0
    get admin_hostel_booking_path(paid), params: { payment_status: ["paid"], order_status: "active", sort: "id", direction: "asc", page: "2" }
    assert_response :success
    assert_select "a[href*='payment_status%5B%5D=paid'][href*='order_status=active'][href*='page=2']"

    get admin_hostel_bookings_path, params: { payment_status: ["not_paid"], order_status: "canceled" }
    assert_response :success
    assert_select "a[href*=?]", "/admin/hostel_bookings/#{canceled.id}", minimum: 1
    assert_match "Order canceled", response.body
    assert_match "Awaiting payment", response.body
  end

  test "admin detail is restricted" do
    booking = users(:two).hostel_bookings.create!(arrival_date: Date.new(2027, 7, 24), departure_date: Date.new(2027, 7, 26), single_rooms: 1)
    sign_in users(:one)
    get admin_hostel_booking_path(booking)
    assert_redirected_to root_path
  end
end

class Admin::HostelBookingsControllerTest
  test "detail only shows order status for canceled orders and omits participants" do
    booking = users(:one).hostel_bookings.create!(arrival_date: Date.new(2027, 7, 24), departure_date: Date.new(2027, 7, 26), single_rooms: 1)
    participant = participants(:one).dup
    participant.egd_pin = nil
    participant.uuid = SecureRandom.uuid
    participant.save!
    booking.order.add_participant_ticket!(participant)
    sign_in users(:admin)

    get admin_hostel_booking_path(booking)
    assert_response :success
    assert_select "dt", text: "Order status", count: 0
    assert_select "h3", text: "Participants in this order", count: 0

    booking.order.submit!
    booking.order.cancel!
    get admin_hostel_booking_path(booking)
    assert_response :success
    assert_select "dd.font-bold.text-red-700", text: "Order canceled"
    assert_select "h3", text: "Participants in this order", count: 0
  end
end
