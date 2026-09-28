require "test_helper"

class ParticipantMailerTest < ActionMailer::TestCase
  test "participant_confirmation asks the registrant to confirm and includes details" do
    participant = participants(:unconfirmed)
    email = ParticipantMailer.participant_confirmation(participant)

    assert_equal [participant.email], email.to
    assert_equal "EGC 2027 – Please confirm your registration", email.subject

    body = email.body.decoded
    assert_match "Thank you for registering", body
    assert_match "confirm your registration", body
    assert_match "suspect someone is trying to abuse", body
    assert_match "#{participant.first_name} #{participant.last_name}", body
    assert_match participant.country, body
    assert_match participant.club, body
    assert_match participant.rank_grade, body
    confirmation_url = Rails.application.routes.url_helpers.confirm_participant_url(participant, token: participant.confirmation_token, host: "example.com")
    assert_match confirmation_url, body
  end

  test "payment_confirmation is sent to the participant" do
    payment = payments(:paid_payment)
    email = ParticipantMailer.payment_confirmation(payment)

    assert_equal [payment.participant.email], email.to
    assert_equal "EGC 2027 – Payment received", email.subject
    assert_match payment.description, email.body.decoded
    assert_match payment.amount_formatted, email.body.decoded
  end
end
