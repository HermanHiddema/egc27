class HostelBookingsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:webhook]
  skip_before_action :verify_authenticity_token, only: [:webhook]

  before_action :set_hostel_booking, only: [:show, :pay]

  def index
    @hostel_bookings = current_user.hostel_bookings.order(created_at: :desc)
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
    @hostel_booking.refresh_from_mollie unless @hostel_booking.paid?
    @show_simulation_controls = mollie_simulation_enabled? && @hostel_booking.payable?
  end

  def pay
    checkout
  end

  def webhook
    HostelBooking.sync_from_mollie_webhook(params[:id])

    head :ok
  rescue Mollie::Exception => e
    Rails.logger.error "[Mollie] Webhook error for hostel booking payment #{params[:id]}: #{e.message}"
    head :service_unavailable
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
      @hostel_booking.simulate_mollie_status!(params[:simulate_status])
      return redirect_to hostel_booking_path(@hostel_booking),
        notice: "Simulated Mollie payment status: #{@hostel_booking.status}."
    end

    checkout_url = @hostel_booking.with_lock do
      next unless @hostel_booking.payable?

      resumed_checkout_url = @hostel_booking.resume_mollie_checkout!
      if @hostel_booking.payable?
        resumed_checkout_url || @hostel_booking.start_mollie_checkout!(
          redirect_url: hostel_booking_url(@hostel_booking),
          webhook_url: webhook_hostel_bookings_url
        )
      end
    end

    return redirect_to hostel_booking_path(@hostel_booking), notice: "Your hostel booking has been paid." if @hostel_booking.paid?
    return redirect_to hostel_booking_path(@hostel_booking), alert: "This hostel booking can not be paid anymore." unless @hostel_booking.payable?

    redirect_to checkout_url, allow_other_host: true
  rescue Mollie::Exception => e
    redirect_to hostel_booking_path(@hostel_booking), alert: "Payment could not be started: #{e.message}"
  end

  def simulate_mollie_payment?
    mollie_simulation_enabled? && params[:simulate_status].in?(HostelBooking::STATUSES)
  end

  def mollie_simulation_enabled?
    Rails.application.config.x.payments.simulate_mollie && (Rails.env.development? || Rails.env.test?)
  end
end
