require "application_system_test_case"

class ParticipantsDuplicateRegistrationTest < ApplicationSystemTestCase
  test "warns when an EGD pin is already registered and links to the alter flow" do
    visit new_participant_path

    page.execute_script(<<~JS)
      window.fetch = async (input, init) => {
        const url = String(input)

        if (url.includes("egd_registered") && url.includes("egd_pin=12345678")) {
          return {
            ok: true,
            json: async () => ({
              registered: true,
              alter_url: "/participants/alter_registration?egd_pin=12345678"
            })
          }
        }

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

    notice = find("[data-egd-autocomplete-target='registeredNotice']")
    assert_text "That EGD Entry is already registered. Do you want to alter your registration?"
    assert_includes notice.text, "Click here to do that"

    link = notice.find("a")
    assert_equal "Click here to do that", link.text
    assert_includes link[:href], "/participants/alter_registration?egd_pin=12345678"
  end
end
