require "test_helper"

class PagesAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access new page" do
    sign_in users(:one)
    get new_page_path
    assert_redirected_to root_path
  end

  test "regular user cannot create page" do
    sign_in users(:one)
    assert_no_difference "Page.count" do
      post pages_path, params: { page: { title: "Test", slug: "test", content: "Content" } }
    end
    assert_redirected_to root_path
  end

  test "regular user cannot edit page" do
    sign_in users(:one)
    get edit_page_path(pages(:one))
    assert_redirected_to root_path
  end

  test "editor can access new page" do
    sign_in users(:editor)
    get new_page_path
    assert_response :success
  end

  test "editor can create page" do
    sign_in users(:editor)
    assert_difference "Page.count", 1 do
      post pages_path, params: { page: { title: "New Page", slug: "new-page", content: "Some content" } }
    end
  end

  test "editor cannot destroy page" do
    sign_in users(:editor)
    assert_no_difference "Page.count" do
      delete page_path(pages(:one))
    end
    assert_redirected_to root_path
    assert Page.exists?(pages(:one).id)
  end

  test "admin can destroy page" do
    sign_in users(:admin)
    assert_difference "Page.count", -1 do
      delete page_path(pages(:one))
    end
    assert_redirected_to pages_path
    refute Page.exists?(pages(:one).id)
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end
end
