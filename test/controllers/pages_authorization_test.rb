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

  test "regular user cannot update page" do
    sign_in users(:one)
    patch page_path(pages(:one)), params: { page: { title: "Changed" } }
    assert_redirected_to root_path
    assert_equal pages(:one).title, pages(:one).reload.title
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

  test "editor can edit page" do
    sign_in users(:editor)
    get edit_page_path(pages(:one))
    assert_response :success
  end

  test "editor cannot destroy page" do
    sign_in users(:editor)
    assert_no_difference "Page.count" do
      delete page_path(pages(:one))
    end
    assert_redirected_to root_path
    assert Page.exists?(pages(:one).id)
  end

  test "admin can access new page" do
    sign_in users(:admin)
    get new_page_path
    assert_response :success
  end

  test "admin can edit page" do
    sign_in users(:admin)
    get edit_page_path(pages(:one))
    assert_response :success
  end

  test "admin can destroy page" do
    sign_in users(:admin)
    assert_difference "Page.count", -1 do
      delete page_path(pages(:one))
    end
    assert_redirected_to pages_path
    refute Page.exists?(pages(:one).id)
  end
end
