require "test_helper"

class NoticesAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access new notice" do
    sign_in users(:one)
    get new_notice_path
    assert_redirected_to root_path
  end

  test "regular user cannot create notice" do
    sign_in users(:one)
    assert_no_difference "Notice.count" do
      post notices_path, params: { notice: { title: "Test", body: "Body", active: true } }
    end
    assert_redirected_to root_path
  end

  test "regular user cannot edit notice" do
    sign_in users(:one)
    get edit_notice_path(notices(:one))
    assert_redirected_to root_path
  end

  test "regular user cannot update notice" do
    sign_in users(:one)
    patch notice_path(notices(:one)), params: { notice: { title: "Changed" } }
    assert_redirected_to root_path
    assert_equal notices(:one).title, notices(:one).reload.title
  end

  test "regular user does not see notice management buttons" do
    sign_in users(:one)
    get notices_path
    assert_response :success
    assert_select "a", text: "New Notice", count: 0
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0
  end

  test "editor sees create and edit buttons but not delete for notices" do
    sign_in users(:editor)
    get notices_path
    assert_response :success
    assert_select "a", text: "New Notice", count: 1
    assert_select "a", text: "Edit"
    assert_select "button", text: "Delete", count: 0
  end

  test "admin sees delete buttons for notices" do
    sign_in users(:admin)
    get notices_path
    assert_response :success
    assert_select "form[action='#{notice_path(notices(:one))}'] button", text: "Delete"
  end

  test "editor can access new notice page" do
    sign_in users(:editor)
    get new_notice_path
    assert_response :success
    assert_select "h1", text: "New Notice"
  end

  test "editor can create notice" do
    sign_in users(:editor)
    assert_difference "Notice.count", 1 do
      post notices_path, params: {
        notice: {
          title: "Created Notice",
          body: "Created via test",
          active: true
        }
      }
    end
    assert_redirected_to notices_path
    assert_equal "Created Notice", Notice.last.title
  end

  test "editor cannot create notice without title" do
    sign_in users(:editor)
    assert_no_difference "Notice.count" do
      post notices_path, params: { notice: { title: "", body: "Body", active: true } }
    end
    assert_response :unprocessable_entity
  end

  test "editor can access edit notice page" do
    sign_in users(:editor)
    get edit_notice_path(notices(:one))
    assert_response :success
    assert_select "h1", text: "Edit Notice"
  end

  test "editor can update notice" do
    sign_in users(:editor)
    notice = notices(:one)
    patch notice_path(notice), params: { notice: { title: "Updated Title", body: "Updated body.", active: false } }
    assert_redirected_to notices_path
    notice.reload
    assert_equal "Updated Title", notice.title
    assert_not notice.active?
  end

  test "editor cannot destroy notice" do
    sign_in users(:editor)
    assert_no_difference "Notice.count" do
      delete notice_path(notices(:one))
    end
    assert_redirected_to root_path
  end

  test "regular user cannot deactivate or reactivate notices" do
    sign_in users(:one)

    active_notice = notices(:one)
    inactive_notice = notices(:two)

    patch deactivate_notice_path(active_notice)
    assert_redirected_to root_path
    assert active_notice.reload.active?

    patch reactivate_notice_path(inactive_notice)
    assert_redirected_to root_path
    assert_not inactive_notice.reload.active?
  end

  test "editor cannot deactivate or reactivate notices" do
    sign_in users(:editor)

    active_notice = notices(:one)
    inactive_notice = notices(:two)

    patch deactivate_notice_path(active_notice)
    assert_redirected_to root_path
    assert active_notice.reload.active?

    patch reactivate_notice_path(inactive_notice)
    assert_redirected_to root_path
    assert_not inactive_notice.reload.active?
  end

  test "admin can deactivate and reactivate notices" do
    sign_in users(:admin)

    active_notice = notices(:one)
    inactive_notice = notices(:two)

    patch deactivate_notice_path(active_notice)
    assert_redirected_to root_path
    assert_not active_notice.reload.active?

    patch reactivate_notice_path(inactive_notice)
    assert_redirected_to root_path
    assert inactive_notice.reload.active?
  end

  test "admin sees error when deactivation fails" do
    sign_in users(:admin)

    active_notice = notices(:one)
    Notice.stub(:find, active_notice) do
      active_notice.stub(:deactivate, false) do
        patch deactivate_notice_path(active_notice)
      end
    end

    assert_redirected_to root_path
    assert_equal "Notice could not be deactivated.", flash[:alert]
    assert active_notice.reload.active?
  end

  test "admin sees error when reactivation fails" do
    sign_in users(:admin)

    inactive_notice = notices(:two)
    Notice.stub(:find, inactive_notice) do
      inactive_notice.stub(:reactivate, false) do
        patch reactivate_notice_path(inactive_notice)
      end
    end

    assert_redirected_to root_path
    assert_equal "Notice could not be reactivated.", flash[:alert]
    assert_not inactive_notice.reload.active?
  end

  test "admin can delete notice" do
    sign_in users(:admin)
    assert_difference "Notice.count", -1 do
      delete notice_path(notices(:two))
    end
    assert_redirected_to notices_path
  end
end
