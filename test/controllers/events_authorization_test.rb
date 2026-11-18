require "test_helper"

class EventsAuthorizationTest < ActionDispatch::IntegrationTest
  test "unauthenticated user can view events index" do
    get events_path
    assert_response :success
  end

  test "unauthenticated user can view event" do
    get event_path(events(:one))
    assert_response :success
    assert_select "a[href='#{new_user_session_path}']", text: "Sign in"
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

  test "event forms use European dates and reject impossible dates without changing the event" do
    sign_in users(:editor)
    get new_event_path
    assert_response :success
    assert_select "input[type='text'][name='event[starts_at]'][placeholder='dd/mm/yyyy hh:mm']"
    assert_select "button[aria-label='Choose start date']"
    assert_select "button[aria-label='Choose start time']"

    assert_difference "Event.count", 1 do
      post events_path, params: { event: { title: "European date", starts_at: "03/04/2027 09:15", ends_at: "03/04/2027 10:30" } }
    end
    event = Event.order(:id).last
    assert_equal Time.zone.local(2027, 4, 3, 9, 15), event.starts_at
    get edit_event_path(event)
    assert_select "input[name='event[starts_at]'][value='03/04/2027 09:15']"

    patch event_path(event), params: { event: { starts_at: "29/02/2027 09:15" } }
    assert_response :unprocessable_entity
    assert_select "li", text: /must be a valid date and time in dd\/mm\/yyyy hh:mm format/
    assert_select "input[name='event[starts_at]'][value='29/02/2027 09:15']"
    assert_equal Time.zone.local(2027, 4, 3, 9, 15), event.reload.starts_at
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

  test "user with multiple participants can choose one on the event page" do
    sign_in users(:one)

    get event_path(events(:two))

    assert_response :success
    assert_select "select[name='event_registration[participant_id]']"
    assert_select "option", text: "Alice Smith"
    assert_select "option", text: "Carol Smith"
  end

  test "unauthenticated user cannot register for event" do
    assert_no_difference "EventRegistration.count" do
      post event_event_registrations_path(events(:two)), params: {
        event_registration: { participant_id: participants(:one).id }
      }
    end
    assert_redirected_to new_user_session_path
  end

  test "authenticated user can register one of their participants for an event" do
    sign_in users(:one)

    assert_difference "EventRegistration.count", 1 do
      post event_event_registrations_path(events(:two)), params: {
        event_registration: { participant_id: participants(:three).id }
      }
    end

    assert_redirected_to event_path(events(:two))
    assert_equal participants(:three), EventRegistration.order(:id).last.participant
  end

  test "authenticated user cannot register another user's participant" do
    sign_in users(:one)

    assert_no_difference "EventRegistration.count" do
      post event_event_registrations_path(events(:two)), params: {
        event_registration: { participant_id: participants(:two).id }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Select one of your participants to register.", response.body
  end

  test "user without participants cannot register for event" do
    sign_in users(:editor)

    assert_no_difference "EventRegistration.count" do
      post event_event_registrations_path(events(:two)), params: {
        event_registration: { participant_id: participants(:one).id }
      }
    end

    assert_redirected_to event_path(events(:two))
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
