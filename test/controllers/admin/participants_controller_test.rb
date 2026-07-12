require "test_helper"

class Admin::ParticipantsControllerTest < ActionDispatch::IntegrationTest
  test "regular user cannot access admin participants index" do
    sign_in users(:one)
    get admin_participants_path
    assert_redirected_to root_path
  end

  test "editor cannot access admin participants index" do
    sign_in users(:editor)
    get admin_participants_path
    assert_redirected_to root_path
  end

  test "unauthenticated user is redirected to sign in" do
    get admin_participants_path
    assert_redirected_to new_user_session_path
  end

  test "admin sees all participants with email, status and edit link" do
    sign_in users(:admin)
    get admin_participants_path

    assert_response :success
    # Includes unconfirmed participants (unlike the public list)
    assert_match "Dave Pending", response.body
    # Shows email addresses
    assert_match "dave@example.org", response.body
    # Status badges for the three states (now the 6th column after the number)
    assert_select "tbody tr td:nth-child(6) span", text: "Pending"
    assert_select "tbody tr td:nth-child(6) span", text: "Confirmed"
    assert_select "tbody tr td:nth-child(6) span", text: "Paid"
    # Participant number (database id offset by 1000) in the first column
    assert_select "tbody tr td:nth-child(1)", text: (participants(:one).id + 1000).to_s
    # Edit link
    assert_select "a[href='#{edit_admin_participant_path(participants(:one))}']", text: "Edit"
  end

  test "admin can open the edit form" do
    sign_in users(:admin)
    get edit_admin_participant_path(participants(:one))

    assert_response :success
    assert_select "form[action='#{admin_participant_path(participants(:one))}']"
    assert_select "input[name='participant[email]'][readonly]"
  end

  test "admin can update participant details" do
    sign_in users(:admin)

    patch admin_participant_path(participants(:one)), params: {
      participant: {
        first_name: "Alicia",
        last_name: "Smith",
        gender: "female",
        age_group: "18-49",
        country: "NL",
        participant_type: "player",
        club: "Rotterdam Go Club"
      }
    }

    assert_redirected_to admin_participants_path
    participant = participants(:one).reload
    assert_equal "Alicia", participant.first_name
    assert_equal "Rotterdam Go Club", participant.club
    assert_equal "alice@example.org", participant.email
  end

  test "admin update with invalid data re-renders the edit form" do
    sign_in users(:admin)

    patch admin_participant_path(participants(:one)), params: {
      participant: { first_name: "" }
    }

    assert_response :unprocessable_entity
    assert_equal "Alice", participants(:one).reload.first_name
  end

  test "editor cannot update a participant" do
    sign_in users(:editor)

    patch admin_participant_path(participants(:one)), params: {
      participant: { first_name: "Hacked" }
    }

    assert_redirected_to root_path
    assert_equal "Alice", participants(:one).reload.first_name
  end

  test "admin can filter by country" do
    sign_in users(:admin)
    get admin_participants_path(country: "DE")

    assert_response :success
    assert_match "Bob Jones", response.body
    assert_no_match "Alice Smith", response.body
  end

  test "admin can filter by status pending" do
    sign_in users(:admin)
    get admin_participants_path(status: "pending")

    assert_response :success
    assert_match "Dave Pending", response.body
    assert_no_match "Alice Smith", response.body
    assert_no_match "Bob Jones", response.body
  end

  test "admin can filter by status paid" do
    sign_in users(:admin)
    get admin_participants_path(status: "paid")

    assert_response :success
    # Bob (fixture two) has a completed payment
    assert_match "Bob Jones", response.body
    assert_no_match "Alice Smith", response.body
    assert_no_match "Dave Pending", response.body
  end

  test "admin can filter by status confirmed" do
    sign_in users(:admin)
    get admin_participants_path(status: "confirmed")

    assert_response :success
    # Alice is confirmed without a completed payment
    assert_match "Alice Smith", response.body
    # Bob is paid, so excluded from the confirmed filter
    assert_no_match "Bob Jones", response.body
    # Dave is unconfirmed
    assert_no_match "Dave Pending", response.body
  end

  test "admin can sort by email ascending" do
    sign_in users(:admin)
    get admin_participants_path(sort: "email", direction: "asc")

    assert_response :success
    emails = css_select("tbody tr td:nth-child(2)").map { |td| td.text.strip }
    assert_equal emails.sort, emails
  end

  test "admin can sort by status" do
    sign_in users(:admin)
    get admin_participants_path(sort: "status", direction: "asc")

    assert_response :success
    statuses = css_select("tbody tr td:nth-child(5)").map { |td| td.text.strip }
    order = { "Pending" => 0, "Confirmed" => 1, "Paid" => 2 }
    assert_equal statuses.sort_by { |status| order[status] }, statuses
  end

  test "invalid sort and status params fall back to defaults" do
    sign_in users(:admin)
    get admin_participants_path(sort: "bogus", status: "bogus")

    assert_response :success
    # Default sort is by name; all participants remain visible
    assert_match "Alice Smith", response.body
    assert_match "Dave Pending", response.body
  end
end
