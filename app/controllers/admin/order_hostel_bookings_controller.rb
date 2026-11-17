class Admin::OrderHostelBookingsController < ApplicationController
  before_action :require_admin!
  before_action :set_order
  before_action :require_editable_order
  before_action :set_booking, only: [:edit, :update]

  def new
    @hostel_booking = @admin_order.user.hostel_bookings.build(arrival_date: HostelPricing::FIRST_ARRIVAL_DATE, departure_date: HostelPricing::LAST_DEPARTURE_DATE)
    render_form
  end

  def create
    @hostel_booking = @admin_order.user.hostel_bookings.build(booking_params)
    @admin_order.with_lock do
      raise ActiveRecord::RecordNotSaved, "Only draft Orders can be edited." unless @admin_order.editable?
      @hostel_booking.save!
      raise ActiveRecord::RecordNotSaved, "Booking was attached to a different Order." unless @hostel_booking.order.id == @admin_order.id
    end
    redirect_to edit_admin_order_path(@admin_order), notice: "Provisional hostel booking added."
  rescue ActiveRecord::RecordInvalid
    render_form(status: :unprocessable_entity)
  rescue ActiveRecord::RecordNotSaved => e
    redirect_to admin_order_path(@admin_order), alert: e.message
  end

  def edit
    render_form
  end

  def update
    @admin_order.with_lock do
      raise ActiveRecord::RecordNotSaved, "Only draft Orders can be edited." unless @admin_order.editable?
      @hostel_booking.update!(booking_params)
      @hostel_booking.reprice!
    end
    redirect_to edit_admin_order_path(@admin_order), notice: "Hostel booking updated."
  rescue ActiveRecord::RecordInvalid
    render_form(status: :unprocessable_entity)
  rescue ActiveRecord::RecordNotSaved => e
    redirect_to admin_order_path(@admin_order), alert: e.message
  end

  private

  def set_order
    @admin_order = Order.find(params[:order_id])
  end

  def require_editable_order
    redirect_to admin_order_path(@admin_order), alert: "Only draft Orders can be edited." unless @admin_order.editable?
  end

  def set_booking
    @hostel_booking = HostelBooking.joins(:product).where(products: { order_id: @admin_order.id }).find(params[:id])
  end

  def booking_params
    params.expect(hostel_booking: [:arrival_date, :departure_date, :breakfasts, *HostelBooking::ROOM_TYPES])
  end

  def render_form(status: :ok)
    @pricing = HostelPricing.new
    render "hostel_bookings/new", status: status
  end
end
