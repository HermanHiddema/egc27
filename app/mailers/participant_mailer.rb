class ParticipantMailer < ApplicationMailer
  def registration_confirmation(participant)
    @participant = participant
    @payment_url = new_participant_payment_url(participant)

    mail(
      to: participant.email,
      subject: "EGC 2027 – Your registration is confirmed"
    )
  end
end
