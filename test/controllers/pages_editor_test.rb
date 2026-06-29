require "test_helper"

class PagesEditorTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
  end

  test "edit page renders TinyMCE editor and pre-fills from rich text content" do
    page = Page.create!(title: "Editor Bridge", slug: "editor-bridge", content: "<p>Existing Trix body</p>")

    get edit_page_path(page, editor: "tinymce")

    assert_response :success
    assert_select "textarea[data-controller=?]", "tinymce"
    assert_select "script[src*=?]", "tinymce"
    assert_includes response.body, "Existing Trix body"
  end

  test "show page renders content_html when present without editor param" do
    page = Page.create!(
      title: "TinyMCE Preferred",
      slug: "tinymce-preferred",
      content: "<p>ActionText body</p>",
      content_html: "<p>TinyMCE body</p>"
    )

    get page_path(page)

    assert_response :success
    assert_includes response.body, "TinyMCE body"
    assert_not_includes response.body, "ActionText body"
  end
end
