require "application_system_test_case"

class ParticipantsCountrySelectorTest < ApplicationSystemTestCase
  test "country label is associated with the country combobox" do
    visit new_participant_path

    country_input = find("[data-egd-autocomplete-target='countryInput']")
    country_label = find("label", text: "Country *")

    assert_equal "participant_country_display", country_input[:id]
    assert_equal "participant_country_display", country_label[:for]
  end

  test "country can be picked and cleared with the clear button" do
    visit new_participant_path

    country_input = find("[data-egd-autocomplete-target='countryInput']")
    country_input.fill_in with: "Netherlands"

    find("[data-egd-autocomplete-target='countryOptions'] button", text: "Netherlands (NL)").click

    assert_equal "NL", find("#participant_country", visible: false).value

    find("[data-egd-autocomplete-target='countryClear']").click

    assert_equal "", find("#participant_country", visible: false).value
    assert_equal "", country_input.value
    assert_equal "false", country_input["aria-expanded"]

    country_input.click

    assert_equal "true", country_input["aria-expanded"]
  end

  test "country can be cleared from the dropdown" do
    visit new_participant_path

    country_input = find("[data-egd-autocomplete-target='countryInput']")
    country_input.fill_in with: "Belgium"
    find("[data-egd-autocomplete-target='countryOptions'] button", text: "Belgium (BE)").click

    assert_equal "BE", find("#participant_country", visible: false).value

    country_input.click
    clear_option = find("[data-egd-autocomplete-target='countryOptions'] button", text: "Clear", exact_text: true)
    assert_equal "-1", clear_option["tabindex"]
    clear_option.click

    assert_equal "", find("#participant_country", visible: false).value
    assert_equal "", country_input.value
    assert_equal "false", country_input["aria-expanded"]
  end

  test "arrow up starts country highlight at the clear option" do
    visit new_participant_path

    country_input = find("[data-egd-autocomplete-target='countryInput']")
    country_input.click
    country_input.send_keys(:arrow_up)

    clear_option = find("[data-egd-autocomplete-target='countryOptions'] button", text: "Clear", exact_text: true)

    assert_equal "true", clear_option["aria-selected"]
    assert_equal clear_option[:id], country_input["aria-activedescendant"]
  end

  test "keyboard highlight updates aria state and clears it when closed" do
    visit new_participant_path

    country_input = find("[data-egd-autocomplete-target='countryInput']")
    country_input.click
    country_input.send_keys(:arrow_down)

    first_option = find("[data-egd-autocomplete-target='countryOptions'] button", match: :first)

    assert_equal "true", first_option["aria-selected"]
    assert_equal first_option[:id], country_input["aria-activedescendant"]
    assert_equal "-1", first_option["tabindex"]

    country_input.send_keys(:escape)

    assert_nil country_input["aria-activedescendant"]
    assert_equal "false", first_option["aria-selected"]
  end

  test "keyboard clear keeps the next dropdown opening available" do
    visit new_participant_path

    country_input = find("[data-egd-autocomplete-target='countryInput']")
    country_input.fill_in with: "Belgium"
    find("[data-egd-autocomplete-target='countryOptions'] button", text: "Belgium (BE)").click

    country_input.click
    country_input.send_keys(:arrow_up)
    country_input.send_keys(:enter)

    assert_equal "", find("#participant_country", visible: false).value
    assert_equal "", country_input.value
    assert_equal "false", country_input["aria-expanded"]

    country_input.send_keys(:arrow_down)

    assert_equal "true", country_input["aria-expanded"]
    refute_nil country_input["aria-activedescendant"]
  end
end
