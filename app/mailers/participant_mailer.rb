class ParticipantMailer < ApplicationMailer
  def payment_confirmation(payment)
    @payment = payment
    @participants = payment.participants.order(:last_name, :first_name, :id)
    @participant = @participants.first
    @hostel_bookings = payment.hostel_bookings

    mail(
      to: payment.order.user.email,
      subject: "EGC 2027 – Payment received"
    )
  end
end
