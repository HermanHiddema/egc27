class Admin::HostelBookingsController < ApplicationController
  PAYMENT_FILTERS = (Payment::STATUSES + %w[unpaid not_paid]).freeze
  ORDER_FILTERS = %w[active canceled].freeze
  SORT_COLUMNS = %w[id booked user arrival amount].freeze

  before_action :require_admin!
  before_action :set_overview_params

  def index
    bookings = HostelBooking.joins(product: :order).includes(:user, order: :payments)
    if @payment_filters.any?
      # Match HostelBooking#current_payment: prefer a paid attempt, then the latest.
      effective_status = "(SELECT payments.status FROM payments WHERE payments.order_id = orders.id ORDER BY (payments.status = 'paid') DESC, payments.created_at DESC, payments.id DESC LIMIT 1)"
      statuses = @payment_filters.flat_map { |status| status == "not_paid" ? Payment::STATUSES - ["paid"] + ["unpaid"] : status }.uniq
      bookings = bookings.where("COALESCE(#{effective_status}, 'unpaid') IN (?)", statuses)
    end
    if @order_filter
      bookings = @order_filter == "active" ? bookings.where(orders: { cancelled_at: nil }) : bookings.where.not(orders: { cancelled_at: nil })
    end
    @sort = @overview_params[:sort] || "booked"
    @direction = @overview_params[:direction] || "desc"
    column = { "id" => HostelBooking.arel_table[:id], "booked" => HostelBooking.arel_table[:created_at], "user" => User.arel_table[:email], "arrival" => HostelBooking.arel_table[:arrival_date], "amount" => HostelBooking.arel_table[:amount_cents] }.fetch(@sort)
    bookings = bookings.joins(:user) if @sort == "user"
    @hostel_bookings = bookings.order(@direction == "asc" ? column.asc : column.desc, HostelBooking.arel_table[:id].desc)
  end

  def show
    @hostel_booking = HostelBooking.includes(:user, order: :payments).find(params[:id])
  end

  private

  def set_overview_params
    @payment_filters = Array(params[:payment_status]).select { |value| PAYMENT_FILTERS.include?(value) }.uniq
    order_filters = Array(params[:order_status]).select { |value| ORDER_FILTERS.include?(value) }.uniq
    @order_filter = order_filters.first if order_filters.one?
    @overview_params = { payment_status: @payment_filters.presence, order_status: @order_filter,
      sort: SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : nil,
      direction: %w[asc desc].include?(params[:direction]) ? params[:direction] : nil,
      page: params[:page].to_s.match?(/\A[1-9]\d*\z/) ? params[:page] : nil }.compact
  end
end
