require "application_system_test_case"

class ParticipantsPhoneInputTest < ApplicationSystemTestCase
  test "phone field is enhanced by the self-hosted intl-tel-input bundle" do
    visit new_participant_path

    assert_selector "[data-phone-input-target='input'].iti__tel-input"
    assert_selector ".iti__country-container button"

    assert page.evaluate_script("window.intlTelInput !== undefined")
  end

  test "phone number is normalized using the self-hosted utils bundle" do
    visit new_participant_path

    phone_input = find("[data-phone-input-target='input']")
    phone_input.fill_in with: "0612345678"
    phone_input.native.send_keys(:tab)

    assert_equal "+31612345678", phone_input.value
  end
end
