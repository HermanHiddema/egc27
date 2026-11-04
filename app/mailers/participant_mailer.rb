class ParticipantMailer < ApplicationMailer
  def payment_confirmation(payment)
    @payment = payment
    @participant = payment.participant

    mail(
      to: @participant.email,
      subject: "EGC 2027 – Payment received"
    )
  end
end
