class CartController < ApplicationController
  # The success page is reached after returning from Mollie and the webhook is an
  # unauthenticated server-to-server callback, so neither can require a session.
  skip_before_action :authenticate_user!, only: [:success, :webhook]
  skip_before_action :verify_authenticity_token, only: [:webhook]

  before_action :load_cart_orders, only: [:show, :checkout]

  def show
  end

  def checkout
    selected = selected_orders

    if selected.empty?
      redirect_to cart_path, alert: "Select at least one item to pay." and return
    end

    reference = SecureRandom.uuid
    order_ids = selected.map(&:id)

    update_orders(order_ids, checkout_reference: reference, status: "pending", mollie_payment_id: nil)

    mollie_payment = Mollie::Payment.create(
      amount: { value: format("%.2f", selected.sum(&:amount_cents) / 100.0), currency: "EUR" },
      description: checkout_description(selected),
      redirect_url: success_cart_url(reference: reference),
      webhook_url: webhook_cart_url,
      metadata: { order_ids: order_ids, user_id: current_user.id }
    )

    update_orders(order_ids, mollie_payment_id: mollie_payment.id)

    redirect_to mollie_payment.checkout_url, allow_other_host: true
  rescue Mollie::Exception => e
    # Roll the selected items back into the cart so the user can retry.
    update_orders(order_ids, status: "cart", checkout_reference: nil, mollie_payment_id: nil)
    redirect_to cart_path, alert: "Payment could not be started: #{e.message}"
  end

  def success
    @orders = Order.for_checkout_reference(params[:reference]).order(created_at: :asc).to_a if params[:reference].present?

    mollie_payment_id = @orders&.first&.mollie_payment_id
    sync_orders(mollie_payment_id) if mollie_payment_id.present?

    @orders = Order.for_checkout_reference(params[:reference]).order(created_at: :asc).to_a if params[:reference].present?
  end

  def webhook
    sync_orders(params[:id])
    head :ok
  rescue Mollie::Exception => e
    Rails.logger.error "[Mollie] Cart webhook error for payment #{params[:id]}: #{e.message}"
    head :ok
  end

  private

  def load_cart_orders
    @orders = current_user.orders.unpaid.order(created_at: :asc).to_a
  end

  def selected_orders
    ids = Array(params[:order_ids]).map(&:to_s)
    @orders.select { |order| ids.include?(order.id.to_s) }
  end

  def update_orders(order_ids, attributes)
    Order.where(id: order_ids).update_all(attributes.merge(updated_at: Time.current))
  end

  def checkout_description(orders)
    if orders.one?
      orders.first.description
    else
      "EGC 2027 – #{orders.size} items"
    end
  end

  def sync_orders(mollie_payment_id)
    return if mollie_payment_id.blank?

    mollie_payment = Mollie::Payment.get(mollie_payment_id)
    paid = mollie_payment.status == "paid"

    Order.for_mollie_payment(mollie_payment.id).update_all(
      status: mollie_payment.status,
      paid_at: paid ? Time.current : nil,
      updated_at: Time.current
    )
  end
end
