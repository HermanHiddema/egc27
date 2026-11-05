require "test_helper"

class ArticleNavigationTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
    @article = articles(:one)
  end

  test "admin overview links preserve context for viewing and editing" do
    get admin_articles_path
    assert_select "a[href='#{article_path(@article, return_to: 'admin')}']"
    assert_select "a[href='#{edit_article_path(@article, return_to: 'admin')}']"

    get edit_article_path(@article, return_to: "admin")
    assert_select "a[href='#{admin_articles_path}']", text: "Cancel"
    assert_select "input[name=return_to][value=admin]"

    get article_path(@article, return_to: "admin")
    assert_select "a[href='#{admin_articles_path}']", text: "← Back to Articles"
    assert_select "a[href='#{edit_article_path(@article, return_to: 'article', overview: 'admin')}']", text: "Edit"

    get edit_article_path(@article, return_to: "article", overview: "admin")
    assert_select "a[href='#{article_path(@article, return_to: 'admin')}']", text: "Cancel"
  end

  test "regular news and article pages return to the page being edited from" do
    get edit_article_path(@article)
    assert_select "a[href='#{articles_path}']", text: "Cancel"

    get article_path(@article)
    assert_select "a[href='#{articles_path}']", text: "← Back to News"
    assert_select "a[href='#{edit_article_path(@article, return_to: 'article')}']", text: "Edit"

    get edit_article_path(@article, return_to: "article")
    assert_select "a[href='#{article_path(@article)}']", text: "Cancel"
  end

  test "context survives validation failure and successful update" do
    patch article_path(@article), params: { return_to: "admin", article: { title: "" } }
    assert_response :unprocessable_entity
    assert_select "a[href='#{admin_articles_path}']", text: "Cancel"
    assert_select "input[name=return_to][value=admin]"

    patch article_path(@article), params: { return_to: "article", overview: "admin", article: { title: "Updated" } }
    assert_redirected_to article_path(@article, return_to: "admin")
  end

  test "unknown return destinations fall back to news" do
    get edit_article_path(@article, return_to: "https://example.com")
    assert_select "a[href='#{articles_path}']", text: "Cancel"
    assert_select "input[name=return_to]", count: 0

    get article_path(@article, return_to: "https://example.com")
    assert_select "a[href='#{articles_path}']", text: "← Back to News"
  end
end
