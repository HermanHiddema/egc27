class HostelBookingsController < ApplicationController
  before_action :set_hostel_booking, only: [:show, :pay]

  def index
    @hostel_bookings = current_user.hostel_bookings.includes(:payments).order(created_at: :desc)
  end

  def new
    @hostel_booking = current_user.hostel_bookings.build(
      arrival_date: HostelPricing::FIRST_ARRIVAL_DATE,
      departure_date: HostelPricing::LAST_DEPARTURE_DATE
    )
    set_pricing
  end

  def create
    @hostel_booking = current_user.hostel_bookings.build(hostel_booking_params)

    if @hostel_booking.save
      redirect_to hostel_booking_path(@hostel_booking), notice: "Your booking has been created. Please review it and complete payment."
    else
      set_pricing
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @payment = @hostel_booking.current_payment
    @payment&.refresh_from_mollie
    @show_simulation_controls = mollie_simulation_enabled? && @hostel_booking.payable?
  end

  def pay
    checkout
  end

  private

  def set_hostel_booking
    @hostel_booking = current_user.hostel_bookings.find(params[:id])
  end

  def set_pricing
    @pricing = HostelPricing.new
  end

  def hostel_booking_params
    params.expect(hostel_booking: [:arrival_date, :departure_date, :breakfasts, *HostelBooking::ROOM_TYPES])
  end

  def checkout
    if simulate_mollie_payment?
      @hostel_booking.with_lock do
        @payment = @hostel_booking.current_payment || Payment.build_for_hostel_booking(@hostel_booking).tap(&:save!)
        @payment.simulate_mollie_status!(params[:simulate_status])
      end
      return redirect_to hostel_booking_path(@hostel_booking), notice: "Simulated Mollie payment status: #{@payment.status}."
    end

    checkout_url = @hostel_booking.with_lock do
      @payment = @hostel_booking.current_payment
      if @payment
        resumed_checkout_url = @payment.resume_mollie_checkout!
        next unless @payment.payable?
        next resumed_checkout_url if resumed_checkout_url.present?
        next hostel_booking_path(@hostel_booking) if @payment.status.in?(Payment::RETRYABLE_MOLLIE_STATUSES)

        @payment = nil if @payment.mollie_payment_id.present?
      end

      @payment ||= Payment.build_for_hostel_booking(@hostel_booking)
      @payment.save! unless @payment.persisted?
      @payment.start_mollie_checkout!(
        redirect_url: hostel_booking_url(@hostel_booking),
        webhook_url: webhook_payments_url
      )
    end

    @payment&.reload
    return redirect_to hostel_booking_path(@hostel_booking), notice: "Your hostel booking has been paid." if @payment&.paid?
    return redirect_to hostel_booking_path(@hostel_booking), alert: "This hostel booking can not be paid anymore." if @payment && !@payment.payable?

    redirect_to checkout_url, allow_other_host: true
  rescue Mollie::Exception => e
    @payment&.destroy if @payment&.persisted? && @payment.mollie_payment_id.blank?
    redirect_to hostel_booking_path(@hostel_booking), alert: "Payment could not be started: #{e.message}"
  end

  def simulate_mollie_payment?
    mollie_simulation_enabled? && params[:simulate_status].in?(Payment::STATUSES)
  end

  def mollie_simulation_enabled?
    Rails.application.config.x.payments.simulate_mollie && (Rails.env.development? || Rails.env.test?)
  end
end
