require "test_helper"

class Admin::NoticesAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access admin notices" do
    sign_in users(:one)
    get admin_notices_path
    assert_redirected_to root_path
  end

  test "editor cannot access admin notices" do
    sign_in users(:editor)
    get admin_notices_path
    assert_redirected_to root_path
  end

  test "admin can list notices" do
    sign_in users(:admin)
    get admin_notices_path
    assert_response :success
    assert_select "h1", text: "Notices"
    assert_select "td", text: notices(:one).title
  end

  test "admin can access new notice page" do
    sign_in users(:admin)
    get new_admin_notice_path
    assert_response :success
    assert_select "h1", text: "New Notice"
  end

  test "admin can create notice" do
    sign_in users(:admin)

    assert_difference "Notice.count", 1 do
      post admin_notices_path, params: {
        notice: {
          title: "Test Notice",
          body: "This is a test notice body.",
          active: true
        }
      }
    end

    assert_redirected_to admin_notices_path
    created = Notice.find_by!(title: "Test Notice")
    assert_equal "This is a test notice body.", created.body
    assert created.active?
  end

  test "admin can access edit notice page" do
    sign_in users(:admin)
    get edit_admin_notice_path(notices(:one))
    assert_response :success
    assert_select "h1", text: "Edit Notice"
  end

  test "admin can update notice" do
    sign_in users(:admin)
    notice = notices(:one)

    patch admin_notice_path(notice), params: {
      notice: {
        title: "Updated Title",
        body: "Updated body.",
        active: false
      }
    }

    assert_redirected_to admin_notices_path
    notice.reload
    assert_equal "Updated Title", notice.title
    assert_equal "Updated body.", notice.body
    assert_not notice.active?
  end

  test "admin can delete notice" do
    sign_in users(:admin)

    assert_difference "Notice.count", -1 do
      delete admin_notice_path(notices(:two))
    end

    assert_redirected_to admin_notices_path
  end
end
