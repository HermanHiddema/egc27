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

    within("[data-egd-autocomplete-target='registeredNotice']") do
      assert_text "That EGD Entry is already registered. Do you want to alter your registration?"
      link = find("a", text: "Click here to do that")
      assert_includes link[:href], "/participants/alter_registration?egd_pin=12345678"
    end
  end

  test "warns when an email already belongs to an account before submit" do
    visit new_participant_path

    page.execute_script(<<~JS)
      window.fetch = async (input, init) => {
        const url = String(input)

        if (url.includes("email_registered")) {
          return {
            ok: true,
            json: async () => ({
              registered: true,
              message: "An account with that email address already exists. Please log in first to register another participant.",
              action_url: "/users/sign_in",
              action_label: "Log in first"
            })
          }
        }

        return {
          ok: true,
          json: async () => []
        }
      }
    JS

    fill_in "participant_email", with: "existing@example.org"

    within("[data-egd-autocomplete-target='existingAccountNotice']") do
      assert_text "An account with that email address already exists."
      link = find("a", text: "Log in first")
      assert_includes link[:href], "/users/sign_in"
    end
  end
end
