class OrdersController < ApplicationController
  before_action :set_draft_order, only: [:show, :add_participant, :remove_product, :submit]
  before_action :set_submitted_order, only: [:show_submitted, :pay_submitted]

  def show
    @products = @order.products.includes(:productable)
  end

  def show_submitted
    @products = @order.products.includes(:productable)
    @latest_payment = @order.payments.order(created_at: :desc, id: :desc).first
    render :show
  end

  def add_participant
    participant = current_user.participants.find_by!(uuid: params[:participant_id])
    @order.with_lock do
      participant.add_ticket_to_draft_order!
      redirect_to order_path, notice: "Ticket added to your draft order."
    end
  rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid => e
    redirect_to order_path, alert: e.message
  end

  def remove_product
    product = @order.products.find(params[:product_id])
    @order.with_lock do
      productable = product.productable
      product.destroy!
      productable.destroy! if productable.is_a?(ParticipantTicket) || productable.is_a?(HostelBooking)
    end
    redirect_to order_path, notice: "Item removed from your draft order."
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to order_path, alert: e.message
  end

  def submit
    @order.submit! if @order.draft?
    start_checkout
  rescue ActiveRecord::RecordInvalid => e
    destination = @order.submitted? ? submitted_order_path(@order) : order_path
    redirect_to destination, alert: e.record.errors.full_messages.to_sentence
  rescue Mollie::Exception => e
    discard_unstarted_payment
    redirect_to submitted_order_path(@order), alert: "Payment could not be started: #{e.message}"
  end

  def pay_submitted
    start_checkout
  rescue ActiveRecord::RecordInvalid => e
    redirect_to submitted_order_path(@order), alert: e.record.errors.full_messages.to_sentence
  rescue Mollie::Exception => e
    discard_unstarted_payment
    redirect_to submitted_order_path(@order), alert: "Payment could not be started: #{e.message}"
  end

  private

  def start_checkout
    if @order.closed?
      redirect_to submitted_order_path(@order), notice: "This order has already been paid."
      return
    end

    payment = @order.payments.pending_or_open.order(created_at: :desc).first
    payment ||= Payment.create!(order: @order, amount_cents: @order.total_cents,
      description: order_description, status: "open")
    @checkout_payment = payment
    checkout_url = payment.resume_mollie_checkout!
    if checkout_url.blank?
      checkout_url = payment.start_mollie_checkout!(
        redirect_url: success_payments_url(token: payment.return_token),
        webhook_url: webhook_payments_url
      )
    end
    redirect_to checkout_url, allow_other_host: true
  end

  def discard_unstarted_payment
    return unless @checkout_payment&.persisted? && @checkout_payment.mollie_payment_id.blank?

    @checkout_payment.destroy!
  end

  def set_draft_order
    @order = current_user.draft_order!
  end

  def set_submitted_order
    @order = current_user.orders.submitted.find(params[:id])
  end

  def order_description
    names = @order.products.includes(:productable).map do |product|
      case product.productable
      when ParticipantTicket then participant_pass_description(product.productable)
      when HostelBooking then product.productable.description
      end
    end
    names.compact.join(", ")
  end

  def participant_pass_description(ticket)
    participant = ticket.participant
    "EGC 2027 pass for #{participant.first_name} #{participant.last_name}"
  end
end
