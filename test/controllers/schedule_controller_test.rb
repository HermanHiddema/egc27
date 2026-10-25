require "test_helper"

class ScheduleControllerTest < ActionDispatch::IntegrationTest
  test "schedule defaults to the event start date on mobile" do
    get schedule_path

    assert_response :success
    assert_select "h2#schedule-day-heading", text: "Choose a day"
    assert_select "select[name='date'] option[selected]", value: "2027-07-24"
    assert_select "h3", text: "Saturday, 24 July 2027"
  end

  test "choosing a date updates the selected day and its events" do
    CalendarEvent.create!(
      title: "Mobile schedule test event",
      starts_at: Time.zone.parse("2027-07-29 10:00"),
      ends_at: Time.zone.parse("2027-07-29 11:00"),
      location: "Main Hall"
    )

    get schedule_path, params: { date: "2027-07-29" }

    assert_response :success
    assert_select "select[name='date'] option[selected]", value: "2027-07-29"
    assert_select "h3", text: "Thursday, 29 July 2027"
    assert_select "a", text: /Mobile schedule test event/
    assert_select "a", text: /Main Hall/
  end

  test "invalid dates return to the first event day" do
    get schedule_path, params: { date: "not-a-date" }

    assert_response :success
    assert_select "select[name='date'] option[selected]", value: "2027-07-24"
  end

  test "week and day calendar views render for the chosen date" do
    selected_date = Date.new(2027, 7, 29)

    get week_calendar_events_path(date: selected_date)

    assert_response :success
    assert_select "[role='region'][aria-label^='Weekly schedule']"
    assert_select "a[href=?]", day_calendar_events_path(date: selected_date)

    get day_calendar_events_path(date: selected_date)

    assert_response :success
    assert_select ".bg-gray-50 h2", text: "Thursday, 29 July 2027"
  end
end
