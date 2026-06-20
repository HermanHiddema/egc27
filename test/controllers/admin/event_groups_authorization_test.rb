require "test_helper"

class Admin::EventGroupsAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access admin event groups" do
    sign_in users(:one)
    get admin_event_groups_path
    assert_redirected_to root_path
  end

  test "editor cannot access admin event groups" do
    sign_in users(:editor)
    get admin_event_groups_path
    assert_redirected_to root_path
  end

  test "admin can list admin event groups" do
    sign_in users(:admin)
    get admin_event_groups_path
    assert_response :success
    assert_select "h1", text: "Event Groups"
  end

  test "admin can create admin event group" do
    sign_in users(:admin)

    assert_difference "EventGroup.count", 1 do
      post admin_event_groups_path, params: {
        event_group: {
          key: "admin_created_group",
          name: "Admin Created Group",
          color: "#dbeafe"
        }
      }
    end

    assert_redirected_to admin_event_groups_path
  end

  test "admin can update admin event group" do
    sign_in users(:admin)
    event_group = EventGroup.create!(key: "admin_update_group", name: "Before Name", color: "#93c5fd")

    patch admin_event_group_path(event_group), params: {
      event_group: {
        name: "After Name"
      }
    }

    assert_redirected_to admin_event_groups_path
    assert_equal "After Name", event_group.reload.name
  end

  test "admin can destroy admin event group" do
    sign_in users(:admin)
    event_group = EventGroup.create!(key: "admin_delete_group", name: "Delete Me", color: "#93c5fd")

    assert_difference "EventGroup.count", -1 do
      delete admin_event_group_path(event_group)
    end

    assert_redirected_to admin_event_groups_path
  end
end
