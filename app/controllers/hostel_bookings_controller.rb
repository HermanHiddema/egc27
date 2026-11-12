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
      redirect_to order_path, notice: "Your booking has been added. Review your order before continuing to payment."
    else
      set_pricing
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @payment = @hostel_booking.current_payment
    @payment&.refresh_from_mollie
  end

  def pay
    order = @hostel_booking.order
    redirect_to(order.draft? ? order_path : submitted_order_path(order))
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
end
