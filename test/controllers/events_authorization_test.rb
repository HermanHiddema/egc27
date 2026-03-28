require "test_helper"

class EventsAuthorizationTest < ActionDispatch::IntegrationTest
  test "unauthenticated user can view events index" do
    get events_path
    assert_response :success
  end

  test "unauthenticated user can view event" do
    get event_path(events(:one))
    assert_response :success
  end

  test "regular user cannot access new event" do
    sign_in users(:one)
    get new_event_path
    assert_redirected_to root_path
  end

  test "regular user cannot create event" do
    sign_in users(:one)
    assert_no_difference "Event.count" do
      post events_path, params: { event: { title: "Test", starts_at: 1.day.from_now, ends_at: 2.days.from_now } }
    end
    assert_redirected_to root_path
  end

  test "regular user cannot edit event" do
    sign_in users(:one)
    get edit_event_path(events(:one))
    assert_redirected_to root_path
  end

  test "regular user cannot delete event" do
    sign_in users(:one)
    assert_no_difference "Event.count" do
      delete event_path(events(:one))
    end
    assert_redirected_to root_path
  end

  test "editor can create event" do
    sign_in users(:editor)
    assert_difference "Event.count", 1 do
      post events_path, params: { event: {
        title: "New Event",
        starts_at: "2026-08-01T10:00",
        ends_at: "2026-08-01T12:00"
      } }
    end
  end

  test "editor can edit event" do
    sign_in users(:editor)
    get edit_event_path(events(:one))
    assert_response :success
  end

  test "editor cannot delete event" do
    sign_in users(:editor)
    assert_no_difference "Event.count" do
      delete event_path(events(:one))
    end
    assert_redirected_to root_path
  end

  test "admin can delete event" do
    sign_in users(:admin)
    assert_difference "Event.count", -1 do
      delete event_path(events(:one))
    end
    assert_redirected_to events_path
  end

  test "unauthenticated user can register for event" do
    assert_difference "EventRegistration.count", 1 do
      post event_event_registrations_path(events(:two)), params: {
        event_registration: { email: participants(:one).email }
      }
    end
    assert_redirected_to event_path(events(:two))
  end

  test "registration with unknown email shows error" do
    assert_no_difference "EventRegistration.count" do
      post event_event_registrations_path(events(:two)), params: {
        event_registration: { email: "nobody@example.org" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "admin can remove event registration" do
    sign_in users(:admin)
    assert_difference "EventRegistration.count", -1 do
      delete event_event_registration_path(events(:one), event_registrations(:one))
    end
    assert_redirected_to event_path(events(:one))
  end

  test "regular user cannot remove event registration" do
    sign_in users(:one)
    assert_no_difference "EventRegistration.count" do
      delete event_event_registration_path(events(:one), event_registrations(:one))
    end
    assert_redirected_to root_path
  end
end
