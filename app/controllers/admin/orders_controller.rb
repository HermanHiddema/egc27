class Admin::OrdersController < ApplicationController
  SORT_COLUMNS = %w[order_id submitted user cancelled_at total].freeze
  STATUS_FILTERS = %w[awaiting pending paid failed canceled expired order_cancelled].freeze

  before_action :require_admin!

  def index
    @sort = SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : "submitted"
    @direction = params[:direction] == "asc" ? :asc : :desc
    requested_statuses = params[:status].is_a?(Array) ? params[:status] : [params[:status]]
    @status_filters = requested_statuses.select { |status| STATUS_FILTERS.include?(status) }.uniq

    orders = Order.submitted.includes(:user, :products, :payments).to_a
    orders.select! { |order| @status_filters.include?(status_filter_key(order)) } if @status_filters.any?
    @orders = sort_orders(orders)
  end

  def show
    @order = Order.includes(:user, :products, :payments, :versions).find(params[:id])
    @products = @order.products_for_display
    @payments = @order.payments.order(created_at: :desc, id: :desc)
    @versions = @order.versions.order(created_at: :desc)
    @cancellation_versions = @versions.select { |version| version.changeset&.dig("cancelled_at")&.last.present? }
    actor_ids = @cancellation_versions.filter_map { |version| Integer(version.whodunnit, exception: false) }
    @version_actors = User.where(id: actor_ids).index_by(&:id)
  end

  def cancel
    order = Order.find(params[:id])
    order.cancel!

    redirect_to admin_orders_path, notice: "Order #{order.id} was cancelled."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_orders_path, alert: "Order could not be cancelled: #{e.record.errors.full_messages.to_sentence}"
  end

  private

  def status_filter_key(order)
    return "order_cancelled" if order.cancelled?

    payments = order.payments.sort_by { |payment| [payment.created_at, payment.id] }.reverse
    return "paid" if payments.any?(&:paid?)
    return "pending" if payments.any? { |payment| !payment.unsuccessful? }
    return "awaiting" if payments.empty?

    payments.first.status
  end

  def sort_orders(orders)
    values = orders.map do |order|
      value = case @sort
      when "order_id" then order.id
      when "user" then order.user.display_name.to_s.downcase
      when "cancelled_at" then order.cancelled_at
      when "total" then order.products.sum { |product| product.price_cents.to_i }
      else order.created_at
      end
      [order, value]
    end

    non_nil, nil_values = values.partition { |_order, value| value.present? }
    sorted = non_nil.sort_by { |_order, value| value }
    sorted.reverse! if @direction == :desc
    (sorted + nil_values).map(&:first)
  end
end
