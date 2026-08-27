require "test_helper"

class PagesAuthorizationTest < ActionDispatch::IntegrationTest
  def image_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.png"), "image/png")
  end

  test "visitors can view public pages" do
    get page_path(pages(:one))

    assert_response :success
  end

  test "visitors are sent to sign in for pages that require authentication" do
    get page_path(pages(:members_only))

    assert_redirected_to new_user_session_path
  end

  test "signed-in users can view pages that require authentication" do
    sign_in users(:one)
    get page_path(pages(:members_only))

    assert_response :success
  end

  test "pages index hides pages that require authentication from visitors" do
    get pages_path

    assert_response :success
    assert_select "a[href='#{page_path(pages(:one))}']", count: 1
    assert_select "a[href='#{page_path(pages(:members_only))}']", count: 0
  end

  test "pages index lists pages that require authentication for signed-in users" do
    sign_in users(:one)
    get pages_path

    assert_response :success
    assert_select "a[href='#{page_path(pages(:members_only))}']"
  end

  test "menus hide items linking to pages that require authentication" do
    get pages_path

    assert_response :success
    assert_select "a", text: menu_items(:members_only_item).label, count: 0
    assert_select "a", text: menu_items(:members_only_child).label, count: 0
  end

  test "menus show items linking to pages that require authentication once signed in" do
    sign_in users(:one)
    get pages_path

    assert_response :success
    assert_select "a", text: menu_items(:members_only_item).label
  end

  test "editor can set the access level of a page" do
    sign_in users(:editor)

    post pages_path, params: { page: { title: "Restricted", slug: "restricted", content: "Secret", access_level: "authenticated" } }

    assert Page.find_by(slug: "restricted").access_level_authenticated?
  end

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

  test "regular user does not see page management buttons" do
    sign_in users(:one)

    get pages_path
    assert_response :success
    assert_select "a", text: "New Page", count: 0
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0

    get page_path(pages(:one))
    assert_response :success
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0
  end

  test "editor sees page create and edit buttons but not delete" do
    sign_in users(:editor)

    get pages_path
    assert_response :success
    assert_select "a[href='#{new_page_path}']", text: "New Page", count: 1
    assert_select "a[href='#{edit_page_path(pages(:one))}']", text: "Edit", count: 1
    assert_select "form[action='#{page_path(pages(:one))}'] button", text: "Delete", count: 0

    get page_path(pages(:one))
    assert_response :success
    assert_select "a[href='#{edit_page_path(pages(:one))}']", text: "Edit", count: 1
    assert_select "form[action='#{page_path(pages(:one))}'] button", text: "Delete", count: 0
  end

  test "admin sees page delete buttons" do
    sign_in users(:admin)

    get pages_path
    assert_response :success
    assert_select "form[action='#{page_path(pages(:one))}'] button", text: "Delete"

    get page_path(pages(:one))
    assert_response :success
    assert_select "form[action='#{page_path(pages(:one))}'] button", text: "Delete"
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

  test "editor can create page with main image" do
    sign_in users(:editor)

    assert_difference "Page.count", 1 do
      post pages_path, params: {
        page: {
          title: "Page with image",
          slug: "page-with-image",
          content: "Some content",
          main_image: image_upload
        }
      }
    end

    assert Page.last.main_image.attached?
  end

  test "page summaries and detail show main image when attached" do
    sign_in users(:one)
    page = pages(:one)
    page.main_image.attach(image_upload)

    get pages_path
    assert_response :success
    assert_select "img[alt=?]", "#{page.title} main image"

    get page_path(page)
    assert_response :success
    assert_select "img[alt=?]", "#{page.title} main image"
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

  test "editor can remove main image from page" do
    sign_in users(:editor)
    page = pages(:one)
    page.main_image.attach(image_upload)
    assert page.main_image.attached?

    patch page_path(page), params: { page: { remove_main_image: "1" } }
    assert_redirected_to page_path(page)
    assert_not page.reload.main_image.attached?
  end
end
