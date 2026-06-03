require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "home page includes header registration call to action" do
    get root_path

    assert_response :success
    assert_select "a[href='#{new_participant_path}']", text: "Register now"
  end
end
