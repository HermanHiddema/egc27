require "test_helper"

class Admin::HostelBookingsControllerTest < ActionDispatch::IntegrationTest
  test "admin sees all hostel bookings" do
    users(:one).hostel_bookings.create!(
      arrival_date: Date.new(2027, 7, 24),
      departure_date: Date.new(2027, 7, 26),
      female_dorm_beds: 1
    )
    sign_in users(:admin)

    get admin_hostel_bookings_path

    assert_response :success
    assert_match users(:one).email, response.body
  end

  test "non-admin can not see hostel bookings" do
    sign_in users(:one)

    get admin_hostel_bookings_path

    assert_redirected_to root_path
  end
end
