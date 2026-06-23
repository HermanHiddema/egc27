require "test_helper"

class ParticipantMailerTest < ActionMailer::TestCase
  test "payment_confirmation is sent to the participant" do
    payment = payments(:paid_payment)
    email = ParticipantMailer.payment_confirmation(payment)

    assert_equal [payment.participant.email], email.to
    assert_equal "EGC 2027 – Payment received", email.subject
    assert_match payment.description, email.body.decoded
    assert_match payment.amount_formatted, email.body.decoded
  end
end
