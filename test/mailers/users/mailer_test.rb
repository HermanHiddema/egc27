require "test_helper"

class Users::MailerTest < ActionMailer::TestCase
  test "confirmation_instructions for a registration-created user includes participant details" do
    participant = Participant.new(
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.org",
      country: "NL",
      club: "Utrecht",
      rank: 27,
      age_group: "18-49",
      participant_type: "player",
      gender: "female",
      attendance_option: "weekend_only"
    )
    user = User.new(email: "jane@example.org", full_name: "Jane Doe", skip_password_validation: true)
    user.registration_participant = participant

    email = Users::Mailer.confirmation_instructions(user, "token123")

    assert_equal "EGC 2027 – Confirm your account", email.subject
    body = email.body.decoded
    assert_match "Jane Doe", body
    assert_match "Utrecht", body
    assert_match "Weekend only", body
    assert_match "magic link", body
  end

  test "confirmation_instructions for an invited user uses the default email" do
    user = User.new(email: "invitee@example.org", full_name: "Invitee", skip_password_validation: true)

    email = Users::Mailer.confirmation_instructions(user, "token123")

    assert_equal "Confirmation instructions", email.subject
    assert_match "Welcome invitee@example.org", email.body.decoded
  end
end
