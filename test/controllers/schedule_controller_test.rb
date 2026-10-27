require "test_helper"

class ScheduleControllerTest < ActionDispatch::IntegrationTest
  test "schedule defaults to the event start date on mobile" do
    get schedule_path

    assert_response :success
    assert_select "h2#schedule-day-heading", text: "Choose a day"
    assert_select "select[name='date'] option[selected]", value: "2027-07-24"
    assert_select "input[type='submit'][value='Show day']", count: 0
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
    assert_select "p", text: /Fun Go is one of:/, count: 0
  end

  test "Fun Go explanation appears only on a day with a Fun Go event" do
    event_group = EventGroup.create!(key: "fun_go", name: "Fun Go", color: "#e06666")
    CalendarEvent.create!(
      title: "Fun Go",
      event_group: event_group,
      starts_at: Time.zone.parse("2027-07-29 13:00"),
      ends_at: Time.zone.parse("2027-07-29 14:00")
    )

    get schedule_path, params: { date: "2027-07-29" }

    assert_response :success
    assert_select "p", text: /Fun Go is one of:/
    assert_select "a[style='background-color: #e06666;']", text: /Fun Go/
  end

  test "desktop schedule includes the Fun Go explanation at the bottom" do
    get schedule_path

    assert_response :success
    assert_select ".schedule-fun-go-note", text: /Fun Go is one of:/
  end

  test "editor event links preserve the selected day through edit and save" do
    sign_in users(:editor)
    event = CalendarEvent.create!(
      title: "Selected day event",
      starts_at: Time.zone.parse("2027-07-29 10:00"),
      ends_at: Time.zone.parse("2027-07-29 11:00")
    )

    get schedule_path, params: { date: "2027-07-29" }

    edit_path = edit_calendar_event_path(event, date: "2027-07-29")
    assert_select "a[href=?]", edit_path

    get edit_path

    assert_response :success
    assert_select "a[href=?]", schedule_path(date: "2027-07-29"), text: "← Back to events"
    assert_select "input[name='date'][value='2027-07-29']"

    patch calendar_event_path(event), params: {
      date: "2027-07-29",
      calendar_event: { title: "Updated selected day event" }
    }

    assert_redirected_to schedule_path(date: "2027-07-29")
  end

  test "blank event start keeps the persisted date in the edit back link" do
    sign_in users(:editor)
    event = CalendarEvent.create!(
      title: "Blank start event",
      starts_at: Time.zone.parse("2027-07-29 10:00"),
      ends_at: Time.zone.parse("2027-07-29 11:00")
    )

    patch calendar_event_path(event), params: {
      calendar_event: { starts_at: "" }
    }

    assert_response :unprocessable_entity
    assert_select "a[href=?]", schedule_path(date: "2027-07-29"), text: "← Back to events"
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
