require "application_system_test_case"

class AdminParticipantsCountryOrderTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    Warden.test_mode!
  end

  teardown do
    Warden.test_reset!
  end

  test "country filter is ordered by display name after enhancement" do
    login_as users(:admin), scope: :user
    visit admin_participants_path

    assert_text "Participants (Admin)"
    assert_selector "#country option[value='DE']", text: "Germany (DE)"
    assert_selector "#country option[value='CH']", text: "Switzerland (CH)"

    country_codes = all("#country option").map { |option| option["value"] }

    assert_operator country_codes.index("DE"), :<, country_codes.index("CH")
  end
end
