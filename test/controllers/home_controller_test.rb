require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "home page includes header registration call to action" do
    get root_path

    assert_response :success
    assert_select "a[href='#{new_participant_path}']", text: "Register now"
    assert_select "a span.md\\:hidden", text: "EGC 2027"
    assert_select "a span.hidden.md\\:inline", text: "European Go Congress 2027"
    assert_select "p.hidden.md\\:block", text: "'s Hertogenbosch, the Netherlands, 24 Jul - 8 Aug, 2027"
    assert_select "a[aria-label='Discord'][href='https://discord.gg/m8cpSVbhMY']"
  end
end
