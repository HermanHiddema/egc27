require "test_helper"

class ArticlesEditorTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
  end

  test "new article renders the TinyMCE editor" do
    get new_article_path

    assert_response :success
    assert_select "textarea[data-controller=?]", "tinymce"

    document = Nokogiri::HTML(response.body)

    assert document.at_css('label[for="article_content_html"]')
    assert_equal document.at_css('script[src*="tinymce"]')["src"],
                 document.at_css('textarea[data-controller="tinymce"]')["data-tinymce-script-url-value"]
  end

  test "creates an article with TinyMCE html content" do
    assert_difference "Article.count", 1 do
      post articles_path, params: {
        article: { title: "TinyMCE Article", content_html: "<p>Powerful editor</p>" }
      }
    end

    article = Article.order(:created_at).last
    assert_equal "<p>Powerful editor</p>", article.content_html
    assert_redirected_to article_path(article)
  end

  test "show article renders content_html" do
    article = Article.create!(
      title: "TinyMCE Preferred",
      content_html: "<p>TinyMCE body</p>",
      user: users(:admin)
    )

    get article_path(article)

    assert_response :success
    assert_includes response.body, "TinyMCE body"
  end
end
