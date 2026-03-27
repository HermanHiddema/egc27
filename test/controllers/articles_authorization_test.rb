require "test_helper"

class ArticlesAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access new article" do
    sign_in users(:one)
    get new_article_path
    assert_redirected_to root_path
  end

  test "regular user cannot create article" do
    sign_in users(:one)
    assert_no_difference "Article.count" do
      post articles_path, params: { article: { title: "Test", content: "Content" } }
    end
    assert_redirected_to root_path
  end

  test "regular user cannot edit article" do
    sign_in users(:one)
    get edit_article_path(articles(:one))
    assert_redirected_to root_path
  end

  test "regular user cannot update article" do
    sign_in users(:one)
    patch article_path(articles(:one)), params: { article: { title: "Changed" } }
    assert_redirected_to root_path
    assert_equal articles(:one).title, articles(:one).reload.title
  end

  test "editor can access new article" do
    sign_in users(:editor)
    get new_article_path
    assert_response :success
  end

  test "editor can create article" do
    sign_in users(:editor)
    assert_difference "Article.count", 1 do
      post articles_path, params: { article: { title: "Test Article", content: "Some content" } }
    end
  end

  test "editor can edit article" do
    sign_in users(:editor)
    get edit_article_path(articles(:one))
    assert_response :success
  end

  test "editor cannot destroy article" do
    sign_in users(:editor)
    assert_no_difference "Article.count" do
      delete article_path(articles(:one))
    end
    assert_redirected_to root_path
    assert Article.exists?(articles(:one).id)
  end

  test "admin can access new article" do
    sign_in users(:admin)
    get new_article_path
    assert_response :success
  end

  test "admin can edit article" do
    sign_in users(:admin)
    get edit_article_path(articles(:one))
    assert_response :success
  end

  test "admin can destroy article" do
    sign_in users(:admin)
    assert_difference "Article.count", -1 do
      delete article_path(articles(:one))
    end
    assert_redirected_to articles_path
    refute Article.exists?(articles(:one).id)
  end
end
