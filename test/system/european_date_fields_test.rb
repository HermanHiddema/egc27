require "application_system_test_case"

class EuropeanDateFieldsTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    Warden.test_mode!
    login_as users(:admin), scope: :user
  end

  teardown { Warden.test_reset! }

  test "choosing a payment date updates the day-first field" do
    visit new_admin_order_payment_path(orders(:three))
    assert_field "Payment date", with: Date.current.strftime("%d/%m/%Y")
    assert_selector "button[aria-label='Choose payment date']"

    page.execute_script(<<~JS)
      const picker = document.querySelector('[data-european-date-target="picker"]');
      picker.value = "2026-04-03";
      picker.dispatchEvent(new Event("change", { bubbles: true }));
    JS

    assert_field "Payment date", with: "03/04/2026"
  end

  test "date and time pickers preserve each other's values" do
    visit new_event_path
    assert_selector "button[aria-label='Choose start date']"
    assert_selector "button[aria-label='Choose start time']"
    fill_in "Start", with: "03/04/2027 09:15"

    page.execute_script(<<~JS)
      const field = document.querySelector('[name="event[starts_at]"]').closest('[data-controller="european-date"]');
      const picker = field.querySelector('[data-european-date-target="picker"]');
      picker.value = "2027-05-04";
      picker.dispatchEvent(new Event("change", { bubbles: true }));
    JS
    assert_field "Start", with: "04/05/2027 09:15"

    page.execute_script(<<~JS)
      const field = document.querySelector('[name="event[starts_at]"]').closest('[data-controller="european-date"]');
      const picker = field.querySelector('[data-european-date-target="timePicker"]');
      picker.value = "10:45";
      picker.dispatchEvent(new Event("change", { bubbles: true }));
    JS
    assert_field "Start", with: "04/05/2027 10:45"
  end
end
