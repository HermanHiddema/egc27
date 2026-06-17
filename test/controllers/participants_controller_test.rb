require "test_helper"

class ParticipantsControllerTest < ActionDispatch::IntegrationTest
  test "participants index is publicly accessible" do
    get participants_path

    assert_response :success
  end

  test "participants index shows presence period column" do
    get participants_path

    assert_response :success
    assert_select "th", text: "Presence"
    body = response.body
    assert_match "✓", body
    assert_match "✗", body
    assert_select "span[aria-label*='Week 1:']"
    assert_select "span[aria-label*='Weekend:']"
    assert_select "span[aria-label*='Week 2:']"
    assert_select "span[aria-label='Week 1: attending']"
    assert_select "span[aria-label='Week 1: not attending']"
  end

  test "participants index supports country filter and shows numbered filtered results with flags" do
    get participants_path, params: { country: "NL" }

    assert_response :success
    assert_select "tbody tr", count: 2
    assert_select "tbody tr td:first-child", text: "1", count: 1
    assert_select "tbody tr td:first-child", text: "2", count: 1
    assert_select "p", text: /2 results/
    assert_select "select[name='country'] option[value='NL'][selected='selected']"
    assert_match "🇳🇱 NL", response.body
    assert_no_match "🇩🇪 DE", response.body
  end

  test "participants index sorts by rank using rank integer values" do
    get participants_path, params: { sort: "rank", direction: "desc" }

    assert_response :success

    body = response.body
    assert_operator body.index("Bob Jones"), :<, body.index("Alice Smith")
    assert_operator body.index("Alice Smith"), :<, body.index("Carol Smith")
    assert_match "Rank ↓", body
  end

  test "registration form is publicly accessible" do
    get new_participant_path

    assert_response :success
    assert_select "input[name='participant[egd_pin]']:not([type='hidden']):not([disabled])"
    assert_select "input[name='participant[accepted_terms_and_conditions]']", count: 0
    assert_select "input[name='participant[accepted_privacy_policy]']", count: 0
    assert_select "input[name='participant[image_use_consent]'][type='radio']", count: 2
    assert_select "input[name='participant[image_use_consent]'][type='radio'][checked]", count: 0
    assert_select "label[for='participant_attendance_option']", text: "Attendance period"
    assert_select "a[href='#{new_participant_path}']", text: "Register now"
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
          age_group: "18-49",
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
          age_group: "18-49",
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

    participant = Participant.order(:id).last
    assert_redirected_to participant_path(participant)
    follow_redirect!
    assert_match "Registration Received", response.body
    assert_match "Registration received", response.body

    assert_equal "jane@example.org", participant.email
    assert_equal "player", participant.participant_type
    assert_equal false, participant.first_week
    assert_equal true, participant.weekend
    assert_equal false, participant.second_week
    assert_nil participant.confirmed_at, "new participant with unconfirmed user should not be confirmed yet"
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
            age_group: "18-49",
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
        age_group: "18-49",
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
      assert_emails 1 do
        post participants_path, params: {
          participant: {
            first_name: "Test",
            last_name: "User",
            email: existing_user.email,
            participant_type: "player",
            age_group: "18-49",
            country: "NL",
            club: "Utrecht",
            gender: "female",
            image_use_consent: false
          }
        }
      end
    end

    participant = Participant.order(:id).last
    assert_equal existing_user, participant.user
    assert_nil participant.confirmed_at, "participant linked to confirmed user should not be auto-confirmed"
  end

  test "sends confirmation email when participant is linked to already-confirmed user" do
    existing_user = users(:one)
    assert existing_user.confirmed?, "fixture user should be confirmed"

    assert_emails 1 do
      post participants_path, params: {
        participant: {
          first_name: "Auto",
          last_name: "Confirmed",
          email: existing_user.email,
          participant_type: "player",
          age_group: "18-49",
          country: "NL",
          club: "Utrecht",
          gender: "male",
          image_use_consent: true
        }
      }
    end

    participant = Participant.order(:id).last
    assert_nil participant.confirmed_at, "participant should not be auto-confirmed"
    assert_not_nil participant.confirmation_token, "confirmation token should be set"
  end

  test "does not confirm participant when user is unconfirmed" do
    post participants_path, params: {
      participant: {
        first_name: "Unconfirmed",
        last_name: "Person",
        email: "unconfirmed_new@example.org",
        participant_type: "player",
        age_group: "18-49",
        country: "DE",
        club: "Berlin",
        gender: "female",
        image_use_consent: false
      }
    }

    participant = Participant.order(:id).last
    assert_nil participant.confirmed_at
  end

  test "confirm action confirms participant with valid token" do
    participant = participants(:unconfirmed)
    assert_nil participant.confirmed_at

    emails = nil
    assert_emails 1 do
      get confirm_participant_path(participant, token: participant.confirmation_token)
      emails = ActionMailer::Base.deliveries
    end

    participant.reload
    assert_not_nil participant.confirmed_at
    assert_nil participant.confirmation_token
    assert_redirected_to new_participant_payment_path(participant)
    assert_equal "EGC 2027 – Your registration is confirmed", emails.last.subject
  end

  test "confirm action rejects invalid token" do
    participant = participants(:unconfirmed)

    assert_emails 0 do
      get confirm_participant_path(participant, token: "wrong_token")
    end

    participant.reload
    assert_nil participant.confirmed_at
    assert_redirected_to root_path
  end

  test "confirm action rejects missing token" do
    participant = participants(:unconfirmed)

    assert_emails 0 do
      get confirm_participant_path(participant, token: "")
    end

    participant.reload
    assert_nil participant.confirmed_at
    assert_redirected_to root_path
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
