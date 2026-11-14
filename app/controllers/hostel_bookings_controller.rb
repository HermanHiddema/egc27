class HostelBookingsController < ApplicationController
  before_action :set_hostel_booking, only: [:show, :edit, :update, :destroy, :pay]

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

  def edit
    return redirect_to order_path, alert: "Only provisional bookings in your shopping basket can be edited." unless draft_booking?

    set_pricing
    render :new
  end

  def update
    return redirect_to order_path, alert: "Only provisional bookings in your shopping basket can be edited." unless draft_booking?

    @hostel_booking.order.with_lock do
      raise ActiveRecord::RecordNotSaved, "This booking is no longer provisional." unless draft_booking?

      @hostel_booking.update!(hostel_booking_params)
      @hostel_booking.reprice!(date: Date.current)
    end
    redirect_to order_path, notice: "Hostel booking updated."
  rescue ActiveRecord::RecordInvalid
    set_pricing
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotSaved => e
    redirect_to order_path, alert: e.message
  end

  def destroy
    return redirect_to order_path, alert: "Only provisional bookings in your shopping basket can be removed." unless draft_booking?

    @hostel_booking.order.with_lock do
      raise ActiveRecord::RecordNotSaved, "This booking is no longer provisional." unless draft_booking?

      @hostel_booking.destroy!
    end
    redirect_to order_path, notice: "Hostel booking removed from your shopping basket."
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to order_path, alert: e.message
  rescue ActiveRecord::RecordNotSaved => e
    redirect_to order_path, alert: e.message
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

  def draft_booking?
    @hostel_booking.order&.editable? && @hostel_booking.payments.empty?
  end

  def hostel_booking_params
    params.expect(hostel_booking: [:arrival_date, :departure_date, :breakfasts, *HostelBooking::ROOM_TYPES])
  end
end
