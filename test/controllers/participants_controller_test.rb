require "test_helper"

class ParticipantsControllerTest < ActionDispatch::IntegrationTest
  test "participants index is publicly accessible" do
    get participants_path

    assert_response :success
  end

  test "participants index shows only confirmed participants" do
    get participants_path

    assert_response :success
    assert_match "Alice Smith", response.body
    assert_match "Bob Jones", response.body
    assert_no_match "Dave Pending", response.body
    assert_select "select[name='country'] option[value='NL']", text: "NL"
    assert_select "select[name='country'] option[value='DE']", text: "DE"
    assert_select "select[name='country'] option[value='BE']", count: 0
  end

  test "mine requires authentication" do
    get mine_participants_path

    assert_redirected_to new_user_session_path
  end

  test "mine shows only the signed in user's participants" do
    sign_in users(:one)

    get mine_participants_path

    assert_response :success
    assert_match "Alice Smith", response.body
    assert_match "Carol Smith", response.body
    assert_no_match "Dave Pending", response.body
    assert_no_match "Bob Jones", response.body
  end

  test "mine redirects to show page when user has only one participant" do
    sign_in users(:two)

    get mine_participants_path

    assert_redirected_to participant_path(participants(:two))
  end

  test "user menu shows singular registration link for one participant" do
    sign_in users(:two)

    get root_path

    assert_response :success
    assert_select "a[href='#{participant_path(participants(:two))}']", text: "My registration"
  end

  test "user menu shows plural registrations link for multiple participants" do
    sign_in users(:one)

    get root_path

    assert_response :success
    assert_select "a[href='#{mine_participants_path}']", text: "My registrations"
  end

  test "participants index shows presence period column" do
    get participants_path

    assert_response :success
    assert_select "th", text: "Presence"
    body = response.body
    assert_match "✅", body
    assert_match "❌", body
    assert_select "span[aria-label*='Week 1:']"
    assert_select "span[aria-label*='Weekend:']"
    assert_select "span[aria-label*='Week 2:']"
    assert_select "span[aria-label='Week 1: attending']"
    assert_select "span[aria-label='Week 1: not attending']"
  end

  test "show looks up the participant by uuid" do
    participant = participants(:one)

    get participant_path(participant)

    assert_response :success
    assert_equal participant.uuid, participant.to_param
    assert_match "Alice Smith", response.body
  end

  test "show does not resolve a participant by sequential id" do
    participant = participants(:one)

    get "/participants/#{participant.id}"

    assert_response :not_found
  end

  test "participants index supports country filter and shows filtered results with flags" do
    get participants_path, params: { country: "NL" }

    assert_response :success
    assert_select "tbody tr", count: 2
    assert_select "p", text: /2 results/
    assert_select "select[name='country'] option[value='NL'][selected='selected']"
    assert_select "td[data-country-code='NL'] img", count: 2
    assert_select "td[data-country-code='DE'] img", count: 0
  end

  test "participants index sorts by rank using rank integer values" do
    get participants_path, params: { sort: "rank", direction: "desc" }

    assert_response :success

    body = response.body
    assert_operator body.index("Bob Jones"), :<, body.index("Alice Smith")
    assert_operator body.index("Alice Smith"), :<, body.index("Carol Smith")
    assert_match "Rank ↓", body
  end

  test "participants index defaults to rank descending then rating descending" do
    get participants_path

    assert_response :success

    body = response.body
    # Bob and Erin share the same rank, so the higher rating (Bob 2100 > Erin 1500) comes first
    assert_operator body.index("Bob Jones"), :<, body.index("Erin Brown")
    assert_operator body.index("Erin Brown"), :<, body.index("Alice Smith")
    assert_operator body.index("Alice Smith"), :<, body.index("Carol Smith")
    assert_match "Rank ↓", body
  end

  test "participants index keeps participants without a rating last regardless of direction" do
    get participants_path, params: { sort: "rating", direction: "desc" }

    assert_response :success
    body = response.body
    # Carol has no rating and must sort last even when descending
    assert_operator body.index("Bob Jones"), :<, body.index("Alice Smith")
    assert_operator body.index("Alice Smith"), :<, body.index("Carol Smith")

    get participants_path, params: { sort: "rating", direction: "asc" }

    assert_response :success
    body = response.body
    # Carol still sorts last when ascending
    assert_operator body.index("Alice Smith"), :<, body.index("Bob Jones")
    assert_operator body.index("Bob Jones"), :<, body.index("Carol Smith")
  end

  test "participants index renders an empty cell for a missing rating" do
    get participants_path

    assert_response :success
    # The rating cell (5th column) for a participant without a rating should be blank
    assert_select "td:nth-child(5)", text: /\A\s*\z/, count: 1
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
    assert_select "a[href='#{new_participant_path}'] span.hidden.lg\\:inline", text: "Register now"
  end

  test "registration form marks mandatory fields with an asterisk" do
    get new_participant_path

    assert_response :success
    assert_select "label[for='participant_first_name']", text: "First name *"
    assert_select "label[for='participant_last_name']", text: "Last name *"
    assert_select "label[for='participant_gender']", text: "Gender *"
    assert_select "label[for='participant_age_group']", text: "Age group *"
    assert_select "label[for='participant_country']", text: "Country *"
    assert_select "label[for='participant_email']", text: "Email *"
    assert_select "label[for='participant_participant_type']", text: "Participant type *"
  end

  test "registration agreement references only the Terms and Conditions" do
    get new_participant_path

    assert_response :success
    assert_select "p.text-gray-800 a[href=?]", page_path("terms-and-conditions"), text: "Terms and Conditions"
    assert_select "p.text-gray-800 a[href=?]", page_path("privacy"), count: 0
    assert_no_match "Privacy Policy", css_select("p.text-gray-800").map(&:text).join(" ")
  end

  test "mobile navigation toggle uses a hamburger icon and no Navigation label" do
    get participants_path

    assert_response :success
    assert_select "button[data-responsive-menu-target='toggle'][aria-controls='site-menu-panel']" do
      assert_select "svg", count: 1
      assert_select "span", text: "Menu"
    end
    assert_select "button[data-responsive-menu-target='toggle']", text: /Navigation/, count: 0
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

  test "does not create a participant with a duplicate EGD pin" do
    assert_no_difference("Participant.count") do
      post participants_path, params: {
        participant: {
          first_name: "Jane",
          last_name: "Doe",
          email: "duplicate-pin@example.org",
          participant_type: "player",
          age_group: "18-49",
          country: "NL",
          club: "Utrecht",
          rank: 27,
          gender: "female",
          image_use_consent: true,
          egd_pin: participants(:one).egd_pin
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Egd pin has already been taken", response.body
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

  test "sends the tailored confirmation email when registering a new participant" do
    post participants_path, params: {
      participant: {
        first_name: "Jane",
        last_name: "Doe",
        email: "tailored@example.org",
        participant_type: "player",
        age_group: "18-49",
        country: "NL",
        club: "Utrecht",
        gender: "female",
        image_use_consent: false
      }
    }

    email = ActionMailer::Base.deliveries.last
    assert_not_nil email
    assert_equal ["tailored@example.org"], email.to
    assert_equal "EGC 2027 – Confirm your account", email.subject
    body = email.body.decoded
    assert_match "Jane Doe", body
    assert_match "Utrecht", body
    assert_match "magic link", body
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

  test "egd_registered reports a registered EGD pin with an alter url" do
    get egd_registered_participants_path, params: { egd_pin: participants(:one).egd_pin }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload["registered"]
    assert_equal alter_registration_participants_path(egd_pin: participants(:one).egd_pin), payload["alter_url"]
  end

  test "egd_registered reports an unregistered EGD pin" do
    get egd_registered_participants_path, params: { egd_pin: "99999999" }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal false, payload["registered"]
    assert_nil payload["alter_url"]
  end

  test "egd_registered treats a blank pin as unregistered" do
    get egd_registered_participants_path, params: { egd_pin: "" }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal false, payload["registered"]
  end

  test "alter_registration sends confirmed users to sign in with a flash" do
    assert users(:one).confirmed?, "fixture user should be confirmed"

    get alter_registration_participants_path, params: { egd_pin: participants(:one).egd_pin }

    assert_redirected_to new_user_session_path
    assert_equal "Login to alter your registration", flash[:notice]
  end

  test "alter_registration redirects unconfirmed users to the confirmation resend page" do
    users(:dave).update_column(:confirmed_at, nil)

    get alter_registration_participants_path, params: { egd_pin: participants(:unconfirmed).egd_pin }

    assert_redirected_to new_user_confirmation_path
    assert_equal "Please confirm your email address to continue.", flash[:notice]
  end

  test "alter_registration uses the oldest matching participant" do
    original_user = User.create!(email: "original@example.org", skip_password_validation: true)
    original_user.update_column(:confirmed_at, nil)
    later_user = User.create!(email: "later@example.org", skip_password_validation: true, confirmed_at: Time.current)

    original_participant = Participant.create!(
      first_name: "Original",
      last_name: "Player",
      email: "original@example.org",
      age_group: "18-49",
      country: "NL",
      club: "Utrecht",
      gender: "male",
      image_use_consent: true,
      user: original_user
    )
    later_participant = Participant.create!(
      first_name: "Later",
      last_name: "Player",
      email: "later@example.org",
      age_group: "18-49",
      country: "DE",
      club: "Berlin",
      gender: "female",
      image_use_consent: true,
      user: later_user
    )

    original_participant.update_columns(egd_pin: "76543210", created_at: 2.days.ago)
    later_participant.update_columns(egd_pin: "76543210", created_at: 1.day.ago)

    get alter_registration_participants_path, params: { egd_pin: "76543210" }

    assert_redirected_to new_user_confirmation_path
    assert_equal "Please confirm your email address to continue.", flash[:notice]
  end

  test "alter_registration redirects to new registration for an unknown pin" do
    get alter_registration_participants_path, params: { egd_pin: "99999999" }

    assert_redirected_to new_participant_path
  end
end
