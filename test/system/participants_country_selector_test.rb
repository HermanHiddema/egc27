require "application_system_test_case"

class ParticipantsCountrySelectorTest < ApplicationSystemTestCase
  test "country can be picked and cleared with the clear button" do
    visit new_participant_path

    country_input = find("[data-egd-autocomplete-target='countryInput']")
    country_input.fill_in with: "Netherlands"

    find("[data-egd-autocomplete-target='countryOptions'] button", text: "Netherlands (NL)").click

    assert_equal "NL", find("#participant_country", visible: false).value

    find("[data-egd-autocomplete-target='countryClear']").click

    assert_equal "", find("#participant_country", visible: false).value
    assert_equal "", find("[data-egd-autocomplete-target='countryInput']").value
  end

  test "country can be cleared from the dropdown" do
    visit new_participant_path

    country_input = find("[data-egd-autocomplete-target='countryInput']")
    country_input.fill_in with: "Belgium"
    find("[data-egd-autocomplete-target='countryOptions'] button", text: "Belgium (BE)").click

    assert_equal "BE", find("#participant_country", visible: false).value

    find("[data-egd-autocomplete-target='countryInput']").click
    find("[data-egd-autocomplete-target='countryOptions'] button", text: "Clear", exact_text: true).click

    assert_equal "", find("#participant_country", visible: false).value
    assert_equal "", find("[data-egd-autocomplete-target='countryInput']").value
  end
end
