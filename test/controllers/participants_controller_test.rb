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
    assert_select "input[name='participant[accepted_terms_and_conditions]']", count: 0
    assert_select "input[name='participant[accepted_privacy_policy]']", count: 0
    assert_select "input[name='participant[image_use_consent]'][type='radio']", count: 2
  end

  test "registration form includes turnstile widget when site key is configured" do
    previous = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
    ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = "1x00000000000000000000AA"
    get new_participant_path
    assert_select "div.cf-turnstile"
  ensure
    if previous.nil?
      ENV.delete("CLOUDFLARE_TURNSTILE_SITE_KEY")
    else
      ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = previous
    end
  end

  test "rejects registration when turnstile verification fails" do
    previous_secret = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
    previous_site = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
    ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = "test-secret-key"
    ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = "1x00000000000000000000AA"
    assert_no_difference("Participant.count") do
      post participants_path, params: {
        participant: {
          first_name: "Jane",
          last_name: "Doe",
          email: "jane@example.org",
          participant_type: "player",
          date_of_birth: "11-02-1995",
          country: "NL",
          gender: "female",
          image_use_consent: true
        }
        # deliberately omitting cf-turnstile-response so token is blank → verify returns false
      }
    end
    assert_response :unprocessable_entity
  ensure
    if previous_secret.nil?
      ENV.delete("CLOUDFLARE_TURNSTILE_SECRET_KEY")
    else
      ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = previous_secret
    end
    if previous_site.nil?
      ENV.delete("CLOUDFLARE_TURNSTILE_SITE_KEY")
    else
      ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = previous_site
    end
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
          gender: "female",
          phone: "+31612345678",
          rating: 1742,
          image_use_consent: true,
          attendance_option: "weekend_only",
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
    assert_equal false, participant.first_week
    assert_equal true, participant.weekend
    assert_equal false, participant.second_week
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
            gender: "female",
            image_use_consent: false
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
        gender: "female",
        image_use_consent: true
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
          gender: "female",
          image_use_consent: false
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
