class ParticipantMailer < ApplicationMailer
  def participant_confirmation(participant)
    @participant = participant
    @confirmation_url = confirm_participant_url(participant, token: participant.confirmation_token)

    mail(
      to: participant.email,
      subject: "EGC 2027 – Please confirm your registration"
    )
  end

  def registration_confirmation(participant)
    @participant = participant
    @payment_url = new_participant_payment_url(participant)

    mail(
      to: participant.email,
      subject: "EGC 2027 – Your registration is confirmed"
    )
  end
end
