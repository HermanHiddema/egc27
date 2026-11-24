require "test_helper"

class Admin::ParticipantTicketsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin) }

  test "shows current ticket details and pricing period from the paid payment date" do
    ticket = participant_tickets(:four)
    ticket.participant.update!(age_group: "0-11", attendance_option: "all_events")
    payment = payments(:manual_payment)
    { Date.new(2026, 8, 31) => "Special", Date.new(2027, 1, 31) => "Early Bird",
      Date.new(2027, 5, 31) => "Regular", Date.new(2027, 6, 1) => "Late Bird" }.each do |date, label|
      payment.update_columns(payment_date: date)
      get admin_participant_ticket_path(ticket)
      assert_response :success
      assert_select "p", text: /Attendance: All events/
      assert_select "p", text: /Age group: 0-11/
      assert_select "p", text: /Age discount: 80%/
      assert_select "p", text: /Payment date: #{date.strftime('%d\/%m\/%Y')}/
      assert_select "p", text: /Pricing period based on payment date: #{label}/
      assert_select "p", text: /Attendance, age group and age discount reflect current participant details and may differ from those used to set the stored ticket price/
    end
  end

  test "does not infer a payment date or tier from an unpaid attempt" do
    get admin_participant_ticket_path(participant_tickets(:one))
    assert_response :success
    assert_select "p", text: /Payment date: —/
    assert_select "p", text: /Pricing period based on payment date: —/
  end

  test "invalid admission is bold and red" do
    get admin_participant_ticket_path(participant_tickets(:one))
    assert_select "p strong.text-red-700", text: "Not valid"

    get admin_participant_ticket_path(participant_tickets(:four))
    assert_select "p", text: /Admission: Valid/
    assert_select "strong.text-red-700", count: 0
  end

  test "requires admin access" do
    sign_out users(:admin)
    sign_in users(:one)
    get admin_participant_ticket_path(participant_tickets(:four))
    assert_redirected_to root_path
  end
end
