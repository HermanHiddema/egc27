require "application_system_test_case"

class ParticipantsPinLookupTest < ApplicationSystemTestCase
  test "pin lookup autofills participant fields" do
    visit new_participant_path

    page.execute_script(<<~JS)
      window.fetch = async (input, init) => {
        const url = String(input)

        if (url.includes("GetPlayerDataByPIN.php") && url.includes("pin=12345678")) {
          return {
            ok: true,
            json: async () => ({
              Retcode: "Ok",
              Name: "Jane",
              Last_Name: "Doe",
              Country_Code: "NL",
              Club: "Utrecht",
              Grade_n: "27",
              Gor: "1742",
              Pin_Player: "12345678"
            })
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

        if (url.includes("GetPlayerDataByPIN.php") && url.includes("pin=87654321")) {
          return {
            ok: true,
            json: async () => ({
              Retcode: "Ok",
              Name: "Mia",
              Last_Name: "Vermeer",
              Country_Code: "BE",
              Club: "Antwerp",
              Grade_n: "31",
              Gor: "2034",
              Pin_Player: "87654321"
            })
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
end
