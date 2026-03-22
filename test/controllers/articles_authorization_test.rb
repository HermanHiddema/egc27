require "test_helper"

class ArticlesAuthorizationTest < ActionDispatch::IntegrationTest
  test "regular user cannot access new article" do
    sign_in users(:one)
    get new_article_path
    assert_redirected_to root_path
  end

  test "regular user cannot create article" do
    sign_in users(:one)
    post articles_path, params: { article: { title: "Test", content: "Content" } }
    assert_redirected_to root_path
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

  test "editor cannot destroy article" do
    sign_in users(:editor)
    delete article_path(articles(:one))
    assert_redirected_to root_path
    assert Article.exists?(articles(:one).id)
  end

  test "admin can destroy article" do
    sign_in users(:admin)
    delete article_path(articles(:one))
    assert_redirected_to articles_path
    refute Article.exists?(articles(:one).id)
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end
end
