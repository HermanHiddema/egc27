require "test_helper"

class ParticipantsControllerTest < ActionDispatch::IntegrationTest
  test "participants index is publicly accessible" do
    get participants_path

    assert_response :success
  end

  test "registration form is publicly accessible" do
    get new_participant_path

    assert_response :success
    assert_select "input[name='participant[egd_pin]']:not([type='hidden']):not([disabled])"
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
          club: "Utrecht",
          rank: 27,
          phone: "+31612345678",
          rating: 1742,
          accepted_terms_and_conditions: true,
          accepted_privacy_policy: true,
          image_use_consent: true,
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

  test "creates a user account when registering a new participant" do
    assert_difference("User.count", 1) do
      assert_emails 1 do
        post participants_path, params: {
          participant: {
            first_name: "Jane",
            last_name: "Doe",
            email: "new_user@example.org",
            participant_type: "player",
            date_of_birth: "11-02-1995",
            country: "NL",
            club: "Utrecht",
            accepted_terms_and_conditions: true,
            accepted_privacy_policy: true
          }
        }
      end
    end

    user = User.find_by(email: "new_user@example.org")
    assert_not_nil user
    assert_equal "Jane Doe", user.full_name
  end

  test "links participant to newly created user" do
    post participants_path, params: {
      participant: {
        first_name: "Jane",
        last_name: "Doe",
        email: "linked_user@example.org",
        participant_type: "player",
        date_of_birth: "11-02-1995",
        country: "NL",
        club: "Utrecht",
        accepted_terms_and_conditions: true,
        accepted_privacy_policy: true
      }
    }

    participant = Participant.order(:id).last
    user = User.find_by(email: "linked_user@example.org")
    assert_not_nil participant.user
    assert_equal user, participant.user
  end

  test "links participant to existing user when email matches" do
    existing_user = users(:one)

    assert_difference("User.count", 0) do
      post participants_path, params: {
        participant: {
          first_name: "Test",
          last_name: "User",
          email: existing_user.email,
          participant_type: "player",
          date_of_birth: "01-01-1990",
          country: "NL",
          club: "Utrecht",
          accepted_terms_and_conditions: true,
          accepted_privacy_policy: true
        }
      }
    end

    participant = Participant.order(:id).last
    assert_equal existing_user, participant.user
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
