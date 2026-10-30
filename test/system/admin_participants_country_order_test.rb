require "application_system_test_case"

class AdminParticipantsCountryOrderTest < ApplicationSystemTestCase
  test "country filter is ordered by display name after enhancement" do
    visit new_user_session_path
    fill_in "user_email", with: users(:admin).email
    fill_in "user_password", with: "password123"
    click_button "Sign in"
    visit admin_participants_path

    country_options = all("#country option").map(&:text)

    assert_operator country_options.index("Germany (DE)"), :<, country_options.index("Switzerland (CH)")
  end
end
