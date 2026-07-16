require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  def listed_emails
    css_select("tbody tr td:nth-child(2)").map { |cell| cell.text.strip }
  end

  test "index shows only admins and editors by default" do
    sign_in users(:admin)
    get users_path

    assert_response :success
    emails = listed_emails
    assert_includes emails, users(:admin).email
    assert_includes emails, users(:editor).email
    assert_not_includes emails, users(:one).email
    assert_not_includes emails, users(:two).email
  end

  test "index can filter by a specific role" do
    sign_in users(:admin)
    get users_path(role: "regular")

    assert_response :success
    emails = listed_emails
    assert_includes emails, users(:one).email
    assert_includes emails, users(:two).email
    assert_not_includes emails, users(:admin).email
    assert_not_includes emails, users(:editor).email
  end

  test "index can show all roles" do
    sign_in users(:admin)
    get users_path(role: "all")

    assert_response :success
    emails = listed_emails
    assert_includes emails, users(:admin).email
    assert_includes emails, users(:editor).email
    assert_includes emails, users(:one).email
    assert_includes emails, users(:two).email
  end

  test "index ignores an unknown role filter and shows staff" do
    sign_in users(:admin)
    get users_path(role: "bogus")

    assert_response :success
    emails = listed_emails
    assert_includes emails, users(:admin).email
    assert_includes emails, users(:editor).email
    assert_not_includes emails, users(:one).email
  end
end
