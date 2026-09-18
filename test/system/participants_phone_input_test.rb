require "application_system_test_case"

class ParticipantsPhoneInputTest < ApplicationSystemTestCase
  test "phone field is enhanced by the self-hosted intl-tel-input bundle" do
    visit new_participant_path

    assert_selector "[data-phone-input-target='input'].iti__tel-input"
    assert_selector ".iti__country-container button"

    assert page.evaluate_script(<<~JS)
      (() => {
        const imports = JSON.parse(document.querySelector("script[type='importmap']").textContent).imports

        return ["intl-tel-input", "intl-tel-input/umd", "intl-tel-input/utils"].every((name) => {
          return new URL(imports[name], window.location.origin).origin === window.location.origin
        })
      })()
    JS

    assert page.evaluate_script("window.intlTelInput !== undefined")
  end

  test "phone number is normalized using the self-hosted utils bundle" do
    visit new_participant_path

    phone_input = find("[data-phone-input-target='input']")
    phone_input.fill_in with: "0612345678"
    phone_input.native.send_keys(:tab)

    assert_selector :field, "participant_phone", with: "+31612345678"
  end

  test "selected country can be cleared after initialization" do
    visit new_participant_path

    assert page.evaluate_script(<<~JS)
      (() => {
        const input = document.querySelector("[data-phone-input-target='input']")
        const iti = window.intlTelInput.getInstance(input)

        try {
          iti.setCountry("")
          return iti.getSelectedCountryData().iso2 == null
        } catch (error) {
          return false
        }
      })()
    JS
  end

  test "instance registry supports map-backed storage" do
    visit new_participant_path

    assert page.evaluate_script(<<~JS)
      (() => {
        const input = document.querySelector("[data-phone-input-target='input']")
        const iti = window.intlTelInput.getInstance(input)
        const originalInstances = window.intlTelInput.instances
        let extraInput
        let extraIti

        try {
          window.intlTelInput.instances = new Map(Object.entries(originalInstances))

          if (window.intlTelInput.getInstance(input) !== iti) return false

          extraInput = document.createElement("input")
          document.body.appendChild(extraInput)
          extraIti = window.intlTelInput(extraInput, { initialCountry: "nl" })

          return window.intlTelInput.getInstance(extraInput) === extraIti
        } catch (error) {
          return false
        } finally {
          if (extraIti) extraIti.destroy()
          if (extraInput) extraInput.remove()
          window.intlTelInput.instances = originalInstances
        }
      })()
    JS
  end
end
