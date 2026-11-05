require "test_helper"

class Admin::ArticlesControllerTest < ActionDispatch::IntegrationTest
  test "overview requires an editor" do
    get admin_articles_path
    assert_redirected_to new_user_session_path

    sign_in users(:one)
    get admin_articles_path
    assert_redirected_to root_path
  end

  test "editor can view and manage articles without delete access" do
    sign_in users(:editor)
    get admin_articles_path

    assert_response :success
    assert_select "a[href='#{new_article_path}']", text: "New Article"
    Article.find_each do |article|
      assert_select "a[href='#{article_path(article, return_to: "admin")}']", text: article.title
      assert_select "a[href='#{edit_article_path(article, return_to: "admin")}']", text: "Edit"
      assert_select "form[action='#{article_path(article)}']", count: 0
    end
  end

  test "admin can delete articles from the overview" do
    sign_in users(:admin)
    get admin_articles_path

    assert_response :success
    assert_select "form[action='#{article_path(articles(:one))}'] button", text: "Delete"
  end

  test "empty overview offers article creation" do
    Article.delete_all
    sign_in users(:editor)
    get admin_articles_path

    assert_response :success
    assert_select "p", text: "No articles yet."
    assert_select "a[href='#{new_article_path}']", text: "Create the first article"
  end
end
