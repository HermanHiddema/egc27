class Admin::OrderPaymentsController < ApplicationController
  before_action :require_admin!
  before_action :set_order

  def new
    OrderRepricingService.call(order: @order) if @order.submitted?
    @order.association(:products).reset
    load_products
    @payment = @order.payments.build(
      amount_cents: @order.total_cents,
      description: "EGC 2027 Order ##{@order.id} (#{@order.products.count} items)",
      provider: "manual", payment_method: "bank_transfer", payment_date: Date.current,
      status: "paid", processed_in_bookkeeping: true
    )
    render "admin/payments/order_new"
  end

  def create
    permitted = payment_params
    price_changed = false
    ActiveRecord::Base.transaction do
      @order.with_lock do
        raise ActiveRecord::RecordNotSaved, "Submit the draft Order before recording payment." if @order.draft?
        raise ActiveRecord::RecordNotSaved, "This Order is canceled." if @order.cancelled?
        raise ActiveRecord::RecordNotSaved, "This Order already has a successful Payment." if @order.payments.completed.exists?
        raise ActiveRecord::RecordNotSaved, "An active Payment already exists for this Order." if @order.payments.pending_or_open.exists?
        OrderRepricingService.call(order: @order)
        if params[:confirmed_total_cents].to_s != @order.total_cents.to_s
          price_changed = true
          next
        end
        @payment = @order.payments.build(permitted.merge(amount_cents: @order.total_cents, provider: "manual", mollie_payment_id: nil, status: "paid"))
        @payment.save!
      end
    end
    if price_changed
      return redirect_to new_admin_order_payment_path(@order), alert: "The Order total changed. Review the complete Order before recording payment."
    end
    redirect_to admin_order_path(@order), notice: "Manual Payment was recorded for Order ##{@order.id}."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    @payment ||= @order.payments.build
    @payment.errors.add(:base, e.message) unless e.is_a?(ActiveRecord::RecordInvalid)
    @order.association(:products).reset
    load_products
    render "admin/payments/order_new", status: :unprocessable_entity
  end

  private

  def set_order
    @order = Order.includes(:products, :payments).find(params[:order_id])
    load_products
  end

  def load_products
    @products = @order.products_for_display
  end

  def payment_params
    params.require(:payment).permit(:description, :payment_method, :payment_date, :reference, :processed_in_bookkeeping)
  end
end
