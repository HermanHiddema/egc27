require "test_helper"

class ParticipantMailerTest < ActionMailer::TestCase
  test "participant_confirmation explains an account already exists and includes details" do
    participant = participants(:one)
    participant.generate_confirmation_token!
    email = ParticipantMailer.participant_confirmation(participant)

    assert_equal [participant.email], email.to
    assert_equal "EGC 2027 – Please confirm your registration", email.subject

    body = email.body.decoded
    assert_match "An account for", body
    assert_match "already exists", body
    assert_match "suspect someone is trying to abuse", body
    assert_match "#{participant.first_name} #{participant.last_name}", body
    assert_match participant.country, body
    assert_match participant.confirmation_token, body
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
