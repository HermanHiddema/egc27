require "application_system_test_case"

class ParticipantsMineRowClickTest < ApplicationSystemTestCase
  test "participant rows open their page from desktop and phone layouts" do
    visit new_user_session_path
    fill_in "user_email", with: users(:one).email
    fill_in "user_password", with: "password123"
    click_button "Sign in"
    visit mine_participants_path

    participant = participants(:one)
    find("tr[data-clickable-row-url-value='#{participant_path(participant)}'] td:nth-child(2)").click
    assert_current_path participant_path(participant)

    visit mine_participants_path
    page.current_window.resize_to(375, 812)

    participant = participants(:three)
    find("tr[data-clickable-row-url-value='#{participant_path(participant)}'] td:nth-child(3)").click
    assert_current_path participant_path(participant)
  end
end
