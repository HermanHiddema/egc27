require "application_system_test_case"

class AdminParticipantsCountryOrderTest < ApplicationSystemTestCase
  test "country filter is ordered by display name after enhancement" do
    visit new_user_session_path
    fill_in "user_email", with: users(:admin).email
    fill_in "user_password", with: "password123"
    click_button "Sign in"
    visit admin_participants_path

    assert_text "Participants (Admin)"
    assert_selector "#country option[value='DE']", text: "Germany (DE)"
    assert_selector "#country option[value='CH']", text: "Switzerland (CH)"

    country_codes = all("#country option").map { |option| option["value"] }

    assert_operator country_codes.index("DE"), :<, country_codes.index("CH")
  end
end
