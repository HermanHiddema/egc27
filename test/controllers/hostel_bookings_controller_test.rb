require "test_helper"
require "ostruct"

class HostelBookingsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  def booking_params(**overrides)
    {
      hostel_booking: {
        arrival_date: "2027-07-24",
        departure_date: "2027-07-26",
        single_rooms: "1",
        double_rooms: "0",
        six_person_rooms: "0",
        mixed_dorm_beds: "2",
        female_dorm_beds: "0",
        breakfasts: "3"
      }.merge(overrides)
    }
  end

  def create_booking(user = users(:one), **attributes)
    user.hostel_bookings.create!({
      arrival_date: Date.new(2027, 7, 24),
      departure_date: Date.new(2027, 7, 26),
      double_rooms: 1
    }.merge(attributes))
  end

  def create_payment(booking, **attributes)
    booking.payments.create!({
      amount_cents: booking.amount_cents,
      description: booking.description
    }.merge(attributes))
  end

  def with_mollie_create_stub(mollie_payment)
    original = Mollie::Payment.method(:create)
    created_params = []
    Mollie::Payment.define_singleton_method(:create) do |**params|
      created_params << params
      mollie_payment
    end
    yield created_params
  ensure
    Mollie::Payment.define_singleton_method(:create, &original)
  end

  def with_mollie_get_stub(mollie_payment)
    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_payment }
    yield
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  def with_mollie_simulation_enabled
    original = Rails.application.config.x.payments.simulate_mollie
    Rails.application.config.x.payments.simulate_mollie = true
    yield
  ensure
    Rails.application.config.x.payments.simulate_mollie = original
  end

  test "requires sign in to book" do
    get new_hostel_booking_path

    assert_redirected_to new_user_session_path
  end

  test "requires sign in to create a booking" do
    assert_no_difference("HostelBooking.count") do
      post hostel_bookings_path, params: booking_params
    end

    assert_redirected_to new_user_session_path
  end

  test "new shows the booking form with current prices" do
    sign_in users(:one)

    travel_to Time.zone.local(2027, 3, 1) do
      get new_hostel_booking_path
    end

    assert_response :success
    assert_select "form[data-controller='hostel-booking']"
    assert_select "select[name='hostel_booking[arrival_date]'] option", count: 14
    assert_select "select[name='hostel_booking[arrival_date]'] option[value='2027-07-24']", text: "Sat, 24 Jul 2027"
    assert_select "select[name='hostel_booking[departure_date]'] option[value='2027-08-07']", text: "Sat, 07 Aug 2027"
    assert_select "input[name='hostel_booking[female_dorm_beds]']"
    assert_select "input[name='hostel_booking[breakfasts]']"
    assert_match "€ 72 per night", response.body
    assert_match "These prices are valid until", response.body
  end

  test "create saves the booking and redirects to its summary without starting payment" do
    sign_in users(:one)

    with_mollie_create_stub(nil) do |created_params|
      travel_to Time.zone.local(2026, 12, 1) do
        assert_difference("HostelBooking.count", 1) do
          post hostel_bookings_path, params: booking_params
        end
      end

      booking = HostelBooking.last
      expected_cents = 2 * (6_900 + 2 * 2_900 + 3 * 985)
      assert_equal expected_cents, booking.amount_cents
      assert_equal Date.new(2026, 12, 1), booking.priced_on
      assert_equal users(:one), booking.user
      assert_empty booking.payments
      assert_equal "unpaid", booking.status
      assert_empty created_params
      assert_redirected_to hostel_booking_path(booking)
      assert_equal "Your booking has been created. Please review it and complete payment.", flash[:notice]
    end

    follow_redirect!

    assert_response :success
    assert_select "form[action=?]", pay_hostel_booking_path(HostelBooking.last)
  end

  test "create re-renders the form for invalid dates" do
    sign_in users(:one)

    assert_no_difference("HostelBooking.count") do
      post hostel_bookings_path, params: booking_params(arrival_date: "2027-07-23", departure_date: "2027-08-08")
    end

    assert_response :unprocessable_entity
    assert_match "can not be before 24 July 2027", response.body
    assert_match "can not be after 7 August 2027", response.body
  end

  test "index lists only the bookings of the current user" do
    own = create_booking
    other = create_booking(users(:two))
    sign_in users(:one)

    get hostel_bookings_path

    assert_response :success
    assert_select "a[href=?]", hostel_booking_path(own)
    assert_select "a[href=?]", hostel_booking_path(other), count: 0
  end

  test "show is limited to the bookings of the current user" do
    other = create_booking(users(:two))
    sign_in users(:one)

    get hostel_booking_path(other)

    assert_response :not_found
  end

  test "show summarizes booked items without prices and lists the price calculation" do
    booking = nil
    travel_to Time.zone.local(2026, 12, 1) do
      booking = create_booking(single_rooms: 1, double_rooms: 0, mixed_dorm_beds: 2, breakfasts: 2)
    end
    sign_in users(:one)

    get hostel_booking_path(booking)

    assert_response :success
    assert_select "#booked-items li", text: "1 × 1-person room"
    assert_select "#booked-items li", text: "2 × 1 bed in a 6-person dorm (mixed)"
    assert_select "#booked-items li", text: "Breakfast buffet for 2 people"
    assert_select "#booked-items", text: /€/, count: 0
    assert_select "td", text: "1 × 1-person room × 2 nights × € 69.00"
    assert_select "td", text: "€ 138.00"
    assert_select "td", text: "2 × mixed dorm bed × 2 nights × € 29.00"
    assert_select "td", text: "€ 116.00"
    assert_select "td", text: "2 × Breakfast buffet × 2 nights × € 9.85"
    assert_select "td", text: "€ 39.40"
    assert_select "tfoot td", text: "€ 293.40"
  end

  test "new has an element for the live price calculation" do
    sign_in users(:one)

    get new_hostel_booking_path

    assert_select "tbody[data-hostel-booking-target='lines']"
    assert_select "form[data-hostel-booking-labels-value*='Breakfast buffet']"
    assert_select "input[type=submit][value='Book with commitment to pay']"
    assert_match "Review your booking and complete payment on the next page.", response.body
    assert_select "form[data-hostel-booking-labels-value*='mixed dorm bed']"
    assert_select "form[data-hostel-booking-labels-value*='female dorm bed']"
    assert_select "dt", text: "Beds"
    assert_select "dt", text: "Guests", count: 0
    assert_select "label", text: /1 bed in a 6-person dorm \(female only\)/
  end

  test "show offers payment for an open booking" do
    booking = create_booking
    sign_in users(:one)

    get hostel_booking_path(booking)

    assert_response :success
    assert_select "form[action=?]", pay_hostel_booking_path(booking)
  end

  test "pay resumes an open Mollie checkout" do
    booking = create_booking
    create_payment(booking, mollie_payment_id: "tr_open")
    sign_in users(:one)
    remote = OpenStruct.new(id: "tr_open", status: "open", checkout_url: "https://example.test/resume")

    with_mollie_get_stub(remote) do
      with_mollie_create_stub(nil) do |created_params|
        post pay_hostel_booking_path(booking)
        assert_empty created_params
      end
    end

    assert_redirected_to "https://example.test/resume"
  end

  test "pay does not replace a pending or authorized Mollie payment without a checkout URL" do
    %w[pending authorized].each do |status|
      booking = create_booking
      payment = create_payment(booking, mollie_payment_id: "tr_#{status}")
      sign_in users(:one)

      with_mollie_get_stub(OpenStruct.new(id: payment.mollie_payment_id, status: status)) do
        with_mollie_create_stub(nil) do |created_params|
          post pay_hostel_booking_path(booking)
          assert_empty created_params
        end
      end

      assert_redirected_to hostel_booking_path(booking)
      assert_equal status, payment.reload.status
      assert_equal 1, booking.payments.count
    end
  end

  test "pay starts a new checkout at the booking price when the previous one expired" do
    booking = nil
    travel_to Time.zone.local(2027, 1, 15) do
      booking = create_booking
      create_payment(booking, mollie_payment_id: "tr_expired")
    end
    sign_in users(:one)
    remote = OpenStruct.new(id: "tr_expired", status: "expired")
    new_payment = OpenStruct.new(id: "tr_new", checkout_url: "https://example.test/new")

    with_mollie_get_stub(remote) do
      with_mollie_create_stub(new_payment) do
        travel_to Time.zone.local(2027, 2, 15) do
          post pay_hostel_booking_path(booking)
        end
      end
    end

    assert_redirected_to "https://example.test/new"
    old_payment, new_payment = booking.payments.reorder(:created_at, :id)
    assert_equal "tr_expired", old_payment.mollie_payment_id
    assert_equal "tr_new", new_payment.mollie_payment_id
    assert_equal "open", new_payment.status
    assert_equal 2 * 7_900, new_payment.amount_cents
  end

  test "pay does not start a checkout for a paid booking" do
    booking = create_booking
    create_payment(booking, mollie_payment_id: "tr_paid", status: "paid")
    sign_in users(:one)

    with_mollie_get_stub(OpenStruct.new(id: "tr_paid", status: "paid")) do
      post pay_hostel_booking_path(booking)
    end

    assert_redirected_to hostel_booking_path(booking)
  end

  test "pay does not start a checkout when Mollie reports that it is already paid" do
    booking = create_booking
    create_payment(booking, mollie_payment_id: "tr_paid")
    sign_in users(:one)

    with_mollie_get_stub(OpenStruct.new(id: "tr_paid", status: "paid")) do
      with_mollie_create_stub(nil) do |created_params|
        post pay_hostel_booking_path(booking)
        assert_empty created_params
      end
    end

    assert_redirected_to hostel_booking_path(booking)
    assert_equal "paid", booking.reload.status
  end

  test "pay can simulate a Mollie status in test" do
    booking = create_booking
    sign_in users(:one)

    with_mollie_simulation_enabled do
      post pay_hostel_booking_path(booking), params: { simulate_status: "paid" }
    end

    assert_redirected_to hostel_booking_path(booking)
    assert_equal "paid", booking.reload.status
  end

  test "webhook updates the booking without authentication" do
    booking = create_booking
    payment = create_payment(booking, mollie_payment_id: "tr_webhook")

    with_mollie_get_stub(OpenStruct.new(id: "tr_webhook", status: "paid")) do
      post webhook_hostel_bookings_path, params: { id: "tr_webhook" }
    end

    assert_response :ok
    assert_equal "paid", booking.reload.status
    assert_equal "paid", payment.reload.status
  end

  test "webhook asks Mollie to retry when fetching the payment fails" do
    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| raise Mollie::Exception, "Mollie is down" }

    post webhook_hostel_bookings_path, params: { id: "tr_unavailable" }

    assert_response :service_unavailable
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end
end
