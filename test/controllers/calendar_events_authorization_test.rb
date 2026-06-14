require "test_helper"

class CalendarEventsAuthorizationTest < ActionDispatch::IntegrationTest
  test "unauthenticated user can view schedule" do
    get schedule_calendar_events_path
    assert_response :success
    assert_match "Calendar — Schedule", response.body
    assert_match "Fri, 24 Jul 2026", response.body
    assert_match "Sat, 08 Aug 2026", response.body
  end

  test "schedule renders event color" do
    get schedule_calendar_events_path

    assert_response :success
    assert_match "background-color: #{calendar_events(:one).color};", response.body
  end

  test "regular user cannot access new calendar event" do
    sign_in users(:one)
    get new_calendar_event_path
    assert_redirected_to root_path
  end

  test "regular user cannot create calendar event" do
    sign_in users(:one)
    assert_no_difference "CalendarEvent.count" do
      post calendar_events_path, params: {
        calendar_event: {
          title: "Test Event",
          starts_at: "2026-08-01 10:00",
          ends_at: "2026-08-01 11:00"
        }
      }
    end
    assert_redirected_to root_path
  end

  test "regular user cannot edit calendar event" do
    sign_in users(:one)
    get edit_calendar_event_path(calendar_events(:one))
    assert_redirected_to root_path
  end

  test "regular user cannot update calendar event" do
    sign_in users(:one)
    patch calendar_event_path(calendar_events(:one)), params: {
      calendar_event: { title: "Changed" }
    }
    assert_redirected_to root_path
    assert_equal calendar_events(:one).title, calendar_events(:one).reload.title
  end

  test "regular user cannot destroy calendar event" do
    sign_in users(:one)
    assert_no_difference "CalendarEvent.count" do
      delete calendar_event_path(calendar_events(:one))
    end
    assert_redirected_to root_path
    assert CalendarEvent.exists?(calendar_events(:one).id)
  end

  test "regular user does not see calendar event management buttons" do
    sign_in users(:one)

    calendar_event_date = calendar_events(:one).starts_at.to_date
    [
      calendar_path(month: calendar_event_date.strftime("%Y-%m")),
      day_calendar_events_path(date: calendar_event_date),
      week_calendar_events_path(date: calendar_event_date),
      schedule_calendar_events_path,
      two_weeks_calendar_events_path(date: calendar_event_date),
      three_weeks_calendar_events_path(date: calendar_event_date),
      list_calendar_events_path(from: calendar_event_date.beginning_of_month, to: calendar_event_date.end_of_month)
    ].each do |path|
      get path
      assert_response :success
      assert_select "a", text: "New Event", count: 0
    end

    get calendar_event_path(calendar_events(:one))
    assert_response :success
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0
  end

  test "editor sees calendar create and edit buttons but not delete" do
    sign_in users(:editor)

    calendar_event_date = calendar_events(:one).starts_at.to_date
    [
      calendar_path(month: calendar_event_date.strftime("%Y-%m")),
      day_calendar_events_path(date: calendar_event_date),
      week_calendar_events_path(date: calendar_event_date),
      schedule_calendar_events_path,
      two_weeks_calendar_events_path(date: calendar_event_date),
      three_weeks_calendar_events_path(date: calendar_event_date),
      list_calendar_events_path(from: calendar_event_date.beginning_of_month, to: calendar_event_date.end_of_month)
    ].each do |path|
      get path
      assert_response :success
      assert_select "a[href='#{new_calendar_event_path}']", text: "New Event", count: 1
    end

    get calendar_event_path(calendar_events(:one))
    assert_response :success
    assert_select "a[href='#{edit_calendar_event_path(calendar_events(:one))}']", text: "Edit", count: 1
    assert_select "form[action='#{calendar_event_path(calendar_events(:one))}'] button", text: "Delete", count: 0
  end

  test "admin sees calendar event delete button" do
    sign_in users(:admin)

    get calendar_event_path(calendar_events(:one))
    assert_response :success
    assert_select "a[href='#{edit_calendar_event_path(calendar_events(:one))}']", text: "Edit", count: 1
    assert_select "form[action='#{calendar_event_path(calendar_events(:one))}'] button", text: "Delete"
  end

  test "editor can access new calendar event" do
    sign_in users(:editor)
    get new_calendar_event_path
    assert_response :success
  end

  test "editor can create calendar event" do
    sign_in users(:editor)
    assert_difference "CalendarEvent.count", 1 do
      post calendar_events_path, params: {
        calendar_event: {
          title: "Test Event",
          starts_at: "2026-08-01 10:00",
          ends_at: "2026-08-01 11:00",
          color: "#86efac"
        }
      }
    end

    assert_equal "#86efac", CalendarEvent.order(:id).last.color
  end

  test "editor can edit calendar event" do
    sign_in users(:editor)
    get edit_calendar_event_path(calendar_events(:one))
    assert_response :success
  end

  test "editor cannot destroy calendar event" do
    sign_in users(:editor)
    assert_no_difference "CalendarEvent.count" do
      delete calendar_event_path(calendar_events(:one))
    end
    assert_redirected_to root_path
    assert CalendarEvent.exists?(calendar_events(:one).id)
  end

  test "admin can access new calendar event" do
    sign_in users(:admin)
    get new_calendar_event_path
    assert_response :success
  end

  test "admin can edit calendar event" do
    sign_in users(:admin)
    get edit_calendar_event_path(calendar_events(:one))
    assert_response :success
  end

  test "admin can destroy calendar event" do
    sign_in users(:admin)
    assert_difference "CalendarEvent.count", -1 do
      delete calendar_event_path(calendar_events(:one))
    end
    assert_redirected_to calendar_path(month: calendar_events(:one).starts_at.strftime("%Y-%m"))
    refute CalendarEvent.exists?(calendar_events(:one).id)
  end
end
