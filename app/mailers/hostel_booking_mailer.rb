class HostelBookingMailer < ApplicationMailer
  def payment_confirmation(payment)
    @payment = payment
    @hostel_booking = payment.hostel_booking
    @user = @hostel_booking.user

    mail(
      to: @user.email,
      subject: "EGC 2027 – Hostel booking paid"
    )
  end
end
