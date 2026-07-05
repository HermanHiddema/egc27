require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Fixtures are inserted directly and bypass the multisearchable callbacks,
    # so rebuild the pg_search documents for the models we search over.
    [Page, Article, Sponsor].each { |model| PgSearch::Multisearch.rebuild(model) }
  end

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
    assert_select "a[href='#{page_path(pages(:two))}']" do
      assert_select "h3", text: "Travel"
    end
  end

  test "finds pages by content" do
    get search_path, params: { q: "congress" }

    assert_response :success
    assert_select "a[href='#{page_path(pages(:one))}']" do
      assert_select "h3", text: pages(:one).title
    end
  end

  test "finds articles by title" do
    get search_path, params: { q: articles(:one).title }

    assert_response :success
    assert_select "a[href='#{article_path(articles(:one))}']" do
      assert_select "h3", text: articles(:one).title
    end
  end

  test "finds sponsors by name" do
    get search_path, params: { q: sponsors(:one).name }

    assert_response :success
    assert_select "h3", text: sponsors(:one).name
  end

  test "finds sponsors by description" do
    get search_path, params: { q: "sponsor description" }

    assert_response :success
    assert_select "h3", text: sponsors(:one).name
  end

  test "matches stemmed variants using the english dictionary" do
    get search_path, params: { q: "traveling" }

    assert_response :success
    assert_select "a[href='#{page_path(pages(:two))}']" do
      assert_select "h3", text: "Travel"
    end
  end

  test "shows message when nothing matches" do
    get search_path, params: { q: "zzzznonexistentquery" }

    assert_response :success
    assert_select "p", text: /No results found/
  end
end
