require "test_helper"

class ArticlesAuthorizationTest < ActionDispatch::IntegrationTest
  def image_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.png"), "image/png")
  end

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

  test "regular user does not see article management buttons" do
    sign_in users(:one)

    get articles_path
    assert_response :success
    assert_select "a", text: "New Article", count: 0
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0

    get article_path(articles(:one))
    assert_response :success
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0
  end

  test "editor sees create and edit buttons but not delete for articles" do
    sign_in users(:editor)

    get articles_path
    assert_response :success
    assert_select "a", text: "New Article", count: 1
    assert_select "a", text: "Edit"
    assert_select "button", text: "Delete", count: 0
  end

  test "admin sees delete buttons for articles" do
    sign_in users(:admin)

    get articles_path
    assert_response :success
    assert_select "form[action='#{article_path(articles(:one))}'] button", text: "Delete"

    get article_path(articles(:one))
    assert_response :success
    assert_select "form[action='#{article_path(articles(:one))}'] button", text: "Delete"
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

  test "editor can create article with main image" do
    sign_in users(:editor)

    assert_difference "Article.count", 1 do
      post articles_path, params: {
        article: {
          title: "Article with image",
          content: "Some content",
          main_image: image_upload
        }
      }
    end

    assert Article.last.main_image.attached?
  end

  test "article summaries and detail show main image when attached" do
    sign_in users(:one)
    article = articles(:one)
    article.main_image.attach(image_upload)

    get articles_path
    assert_response :success
    assert_select "img[alt=?]", "#{article.title} main image"

    get article_path(article)
    assert_response :success
    assert_select "img[alt=?]", "#{article.title} main image"
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

  test "editor can remove main image from article" do
    sign_in users(:editor)
    article = articles(:one)
    article.main_image.attach(image_upload)
    assert article.main_image.attached?

    patch article_path(article), params: { article: { remove_main_image: "1" } }
    assert_redirected_to article_path(article)
    assert_not article.reload.main_image.attached?
  end
end
