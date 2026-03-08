require "test_helper"

class ParticipantsControllerTest < ActionDispatch::IntegrationTest
  test "participants index is publicly accessible" do
    get participants_path

    assert_response :success
  end

  test "registration form is publicly accessible" do
    get new_participant_path

    assert_response :success
  end

  test "creates participant without authentication" do
    assert_difference("Participant.count", 1) do
      post participants_path, params: {
        participant: {
          first_name: "Jane",
          last_name: "Doe",
          email: "jane@example.org",
          participant_type: "player",
          date_of_birth: "11-02-1995",
          country: "NL",
          city: "Utrecht",
          playing_strength: 27,
          rating: 1742,
          egd_pin: "12345678"
        }
      }
    end

    assert_redirected_to new_participant_path
    follow_redirect!
    assert_match "Registration received", response.body

    participant = Participant.order(:id).last
    assert_equal "jane@example.org", participant.email
    assert_equal "player", participant.participant_type
  end

  test "returns json from egd search" do
    # One-letter query returns [] without touching external network.
    get egd_search_participants_path, params: { q: "a" }

    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type

    payload = JSON.parse(response.body)
    assert_equal [], payload
  end
end
