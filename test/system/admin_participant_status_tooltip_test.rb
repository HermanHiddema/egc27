require "application_system_test_case"

class AdminParticipantStatusTooltipTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    Warden.test_mode!
    login_as users(:admin), scope: :user
  end

  teardown { Warden.test_reset! }

  test "repeated clicks toggle the status popover and outside click and escape dismiss it" do
    visit admin_participants_path(name: "Alice Smith")
    button = find("button[aria-label='About Participant status']")
    popup = "#participant-status-help:popover-open"

    button.click
    assert_selector popup
    button.click
    assert_no_selector popup
    button.click
    assert_selector popup
    find("h1").click
    assert_no_selector popup
    button.click
    assert_selector popup
    button.send_keys(:escape)
    assert_no_selector popup
  end
end
