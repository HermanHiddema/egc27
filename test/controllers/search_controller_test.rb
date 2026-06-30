require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "search page is accessible without authentication" do
    get search_path

    assert_response :success
    assert_select "h1", text: "Search"
    assert_select "form[action='#{search_path}'] input[name='q']"
  end

  test "blank query shows no results" do
    get search_path, params: { q: "" }

    assert_response :success
    assert_select "h3", count: 0
  end

  test "finds pages by title" do
    get search_path, params: { q: "Travel" }

    assert_response :success
    assert_select "a[href='#{page_path(pages(:two))}']", text: "Travel"
  end

  test "finds pages by content" do
    get search_path, params: { q: "congress" }

    assert_response :success
    assert_select "a[href='#{page_path(pages(:one))}']", text: pages(:one).title
  end

  test "finds articles by title" do
    get search_path, params: { q: articles(:one).title }

    assert_response :success
    assert_select "a[href='#{article_path(articles(:one))}']", text: articles(:one).title
  end

  test "shows message when nothing matches" do
    get search_path, params: { q: "zzzznonexistentquery" }

    assert_response :success
    assert_select "p", text: /No results found/
  end
end
