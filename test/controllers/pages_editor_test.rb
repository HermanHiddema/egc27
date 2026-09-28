require "test_helper"

class PagesEditorTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
  end

  test "edit page renders TinyMCE editor pre-filled with the stored html" do
    page = Page.create!(title: "Editor Bridge", slug: "editor-bridge", content_html: "<p>Existing body</p>")

    get edit_page_path(page)

    assert_response :success
    assert_select "textarea[data-controller=?]", "tinymce"
    assert_select "script[src*=?]", "tinymce"
    assert_includes response.body, "Existing body"

    document = Nokogiri::HTML(response.body)

    assert document.at_css('label[for="page_content_html"]')
    assert_equal document.at_css('script[src*="tinymce"]')["src"],
                 document.at_css('textarea[data-controller="tinymce"]')["data-tinymce-script-url-value"]
  end

  test "show page renders content_html" do
    page = Page.create!(
      title: "TinyMCE Preferred",
      slug: "tinymce-preferred",
      content_html: "<p>TinyMCE body</p>"
    )

    get page_path(page)

    assert_response :success
    assert_includes response.body, "TinyMCE body"
  end
end
