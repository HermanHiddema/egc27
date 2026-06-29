require "test_helper"

class ArticlesEditorTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
  end

  test "new article renders the TinyMCE editor by default" do
    get new_article_path

    assert_response :success
    assert_select "textarea[data-controller=?]", "tinymce"
    assert_select "trix-editor", count: 0
  end

  test "new article renders the TinyMCE editor when requested via url param" do
    get new_article_path(editor: "tinymce")

    assert_response :success
    assert_select "textarea[data-controller=?]", "tinymce"
    assert_select "trix-editor", count: 0
    assert_select "script[src*=?]", "tinymce"
  end

  test "default editor can be configured via ENV var" do
    with_env("DEFAULT_EDITOR" => "tinymce") do
      get new_article_path

      assert_response :success
      assert_select "textarea[data-controller=?]", "tinymce"
    end
  end

  test "creates an article with TinyMCE html content" do
    assert_difference "Article.count", 1 do
      post articles_path, params: {
        editor: "tinymce",
        article: { title: "TinyMCE Article", content_html: "<p>Powerful editor</p>" }
      }
    end

    article = Article.order(:created_at).last
    assert_equal "<p>Powerful editor</p>", article.content_html
    assert_redirected_to article_path(article)
  end

  private

  def with_env(values)
    originals = values.transform_values { |_| nil }
    values.each_key { |key| originals[key] = ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    originals.each { |key, value| ENV[key] = value }
  end
end
