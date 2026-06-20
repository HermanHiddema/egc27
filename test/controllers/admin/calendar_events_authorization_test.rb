require "test_helper"

class Admin::CalendarEventsAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access admin calendar events" do
    sign_in users(:one)
    get admin_calendar_events_path
    assert_redirected_to root_path
  end

  test "editor cannot access admin calendar events" do
    sign_in users(:editor)
    get admin_calendar_events_path
    assert_redirected_to root_path
  end

  test "admin can list admin calendar events" do
    sign_in users(:admin)
    get admin_calendar_events_path
    assert_response :success
    assert_select "h1", text: "Calendar Events"
  end

  test "admin can create admin calendar event" do
    sign_in users(:admin)
    event_group = EventGroup.create!(key: "admin_group", name: "Admin Group", color: "#dbeafe")

    assert_difference "CalendarEvent.count", 1 do
      post admin_calendar_events_path, params: {
        calendar_event: {
          title: "Admin Created Event",
          starts_at: "2027-07-24 10:00",
          ends_at: "2027-07-24 11:00",
          event_group_id: event_group.id,
          color: ""
        }
      }
    end

    assert_redirected_to admin_calendar_events_path
    assert_nil CalendarEvent.order(:id).last.color
  end

  test "admin can update admin calendar event" do
    sign_in users(:admin)
    calendar_event = calendar_events(:one)

    patch admin_calendar_event_path(calendar_event), params: {
      calendar_event: {
        title: "Updated Admin Event"
      }
    }

    assert_redirected_to admin_calendar_events_path
    assert_equal "Updated Admin Event", calendar_event.reload.title
  end

  test "admin can destroy admin calendar event" do
    sign_in users(:admin)
    calendar_event = calendar_events(:one)

    assert_difference "CalendarEvent.count", -1 do
      delete admin_calendar_event_path(calendar_event)
    end

    assert_redirected_to admin_calendar_events_path
  end
end
