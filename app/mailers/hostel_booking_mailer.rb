class HostelBookingMailer < ApplicationMailer
  def payment_confirmation(payment)
    @payment = payment
    @hostel_bookings = payment.hostel_bookings
    @user = payment.order.user

    mail(
      to: @user.email,
      subject: "EGC 2027 – Hostel booking paid"
    )
  end
end
