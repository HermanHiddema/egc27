require "test_helper"

class CalendarEventsAuthorizationTest < ActionDispatch::IntegrationTest
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
          ends_at: "2026-08-01 11:00"
        }
      }
    end
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
