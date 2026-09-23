require "test_helper"

class FlyerShortcutRoutesTest < ActionDispatch::IntegrationTest
  test "flyer shortcuts redirect to the matching page" do
    %w[cns cnt jp kr].each do |slug|
      get "/#{slug}"
      assert_redirected_to "/pages/#{slug}"
      assert_response 302
    end
  end
end
