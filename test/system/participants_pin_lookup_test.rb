require "application_system_test_case"

class ParticipantsPinLookupTest < ApplicationSystemTestCase
  test "pin lookup autofills participant fields" do
    visit new_participant_path

    page.execute_script(<<~JS)
      window.fetch = async (input, init) => {
        const url = String(input)

        if (url.includes("/participants/egd_search") && url.includes("q=12345678")) {
          return {
            ok: true,
            json: async () => [{
              first_name: "Jane",
              last_name: "Doe",
              country: "NL",
              club: "Utrecht",
              playing_strength: 27,
              playing_strength_label: "3k",
              rating: 1742,
              egd_pin: "12345678"
            }]
          }
        }

        return {
          ok: true,
          json: async () => []
        }
      }
    JS

    fill_in "egd-search", with: "12345678"

    assert_field "participant_first_name", with: "Jane"
    assert_field "participant_last_name", with: "Doe"
    assert_field "participant_club", with: "Utrecht"
    assert_field "participant_rank", with: "27"
    assert_field "participant_rating", with: "1742"

    hidden_pin = find("#participant_egd_pin", visible: false)
    assert_equal "12345678", hidden_pin.value

    hidden_country = find("#participant_country", visible: false)
    assert_equal "NL", hidden_country.value

    country_input = find("[data-egd-autocomplete-target='countryInput']")
    assert_includes country_input.value, "(NL)"
  end

  test "manual EGD pin entry autofills participant fields" do
    visit new_participant_path

    page.execute_script(<<~JS)
      window.fetch = async (input, init) => {
        const url = String(input)

        if (url.includes("/participants/egd_search") && url.includes("q=87654321")) {
          return {
            ok: true,
            json: async () => [{
              first_name: "Mia",
              last_name: "Vermeer",
              country: "BE",
              club: "Antwerp",
              playing_strength: 31,
              playing_strength_label: "2d",
              rating: 2034,
              egd_pin: "87654321"
            }]
          }
        }

        return {
          ok: true,
          json: async () => ({ registered: false })
        }
      }
    JS

    fill_in "EGD PIN", with: "87654321"

    assert_field "participant_first_name", with: "Mia"
    assert_field "participant_last_name", with: "Vermeer"
    assert_field "participant_club", with: "Antwerp"
    assert_field "participant_rank", with: "31"
    assert_field "participant_rating", with: "2034"

    hidden_pin = find("#participant_egd_pin", visible: false)
    assert_equal "87654321", hidden_pin.value

    hidden_country = find("#participant_country", visible: false)
    assert_equal "BE", hidden_country.value
  end

  test "name search requests the app lookup endpoint and renders matching players" do
    visit new_participant_path

    page.execute_script(<<~JS)
      window.fetch = async (input, init) => {
        const url = String(input)
        window.egdLookupRequestUrl = url

        if (url.includes("/participants/egd_search") && url.includes("q=Smith")) {
          return {
            ok: true,
            json: async () => [{
              first_name: "Jane",
              last_name: "Smith",
              country: "NL",
              club: "Utrecht",
              playing_strength: 27,
              playing_strength_label: "3k",
              rating: 1742,
              egd_pin: "12345678"
            }]
          }
        }

        return { ok: true, json: async () => [] }
      }
    JS

    fill_in "egd-search", with: "Smith"

    result = find("[data-egd-autocomplete-target='results'] button", text: "Jane Smith")
    assert_includes page.evaluate_script("window.egdLookupRequestUrl"), "/participants/egd_search?q=Smith"
    result.click

    assert_field "participant_first_name", with: "Jane"
    assert_field "participant_last_name", with: "Smith"
  end
end
