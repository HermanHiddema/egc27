class OrdersController < ApplicationController
  before_action :set_draft_order, only: [:show, :add_participant, :submit, :cancel]
  before_action :set_submitted_order, only: [:show_submitted, :pay_submitted]

  def show
    @requires_confirmation = ticket_products? && !current_user.confirmed?
    OrderRepricingService.call(order: @order, date: Date.current) if @order.draft? && !@requires_confirmation
    @products = @order.products.includes(:productable)
    @show_simulation_controls = mollie_simulation_enabled? && !@order.closed? && !@requires_confirmation
  end

  def show_submitted
    OrderRepricingService.call(order: @order, date: Date.current)
    @products = @order.products.includes(:productable)
    @latest_payment = @order.payments.order(created_at: :desc, id: :desc).first
    @show_simulation_controls = mollie_simulation_enabled? && !@order.closed?
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

  def cancel
    @order.with_lock { @order.destroy! }
    redirect_to root_path, notice: "Your draft order was cancelled. Its items have been removed."
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to submitted_order_path(@order), alert: e.message
  end

  def submit
    if ticket_products? && !current_user.confirmed?
      return redirect_to order_path, alert: "Please confirm your email address before paying for tickets."
    end

    @order.submit! if @order.draft?
    return simulate_order_payment! if simulate_mollie_payment?

    start_checkout
  rescue ActiveRecord::RecordInvalid => e
    destination = @order.submitted? ? submitted_order_path(@order) : order_path
    redirect_to destination, alert: e.record.errors.full_messages.to_sentence
  rescue Mollie::Exception => e
    discard_unstarted_payment
    redirect_to submitted_order_path(@order), alert: "Payment could not be started: #{e.message}"
  end

  def pay_submitted
    return simulate_order_payment! if simulate_mollie_payment?

    start_checkout
  rescue ActiveRecord::RecordInvalid => e
    redirect_to submitted_order_path(@order), alert: e.record.errors.full_messages.to_sentence
  rescue Mollie::Exception => e
    discard_unstarted_payment
    redirect_to submitted_order_path(@order), alert: "Payment could not be started: #{e.message}"
  end

  private

  def ticket_products?
    @order.products.where(productable_type: ParticipantTicket.polymorphic_name).exists?
  end

  def simulate_order_payment!
    payment = @order.payments.pending_or_open.order(created_at: :desc, id: :desc).first
    unless payment
      @order.with_lock do
        OrderRepricingService.call(order: @order, date: Date.current)
        payment = Payment.create!(order: @order, amount_cents: @order.total_cents,
          description: order_description, status: "open")
      end
    end
    payment.simulate_mollie_status!(params[:simulate_status]) unless payment.paid?
    redirect_to success_payments_path(token: payment.return_token)
  end

  def simulate_mollie_payment?
    mollie_simulation_enabled? && params[:simulate_status].in?(Payment::STATUSES)
  end

  def mollie_simulation_enabled?
    Rails.application.config.x.payments.simulate_mollie && (Rails.env.development? || Rails.env.test?)
  end

  def start_checkout
    if @order.closed?
      redirect_to submitted_order_path(@order), notice: "This order has already been paid."
      return
    end

    payment = @order.payments.pending_or_open.order(created_at: :desc).first
    unless payment
      @order.with_lock do
        OrderRepricingService.call(order: @order, date: Date.current)
        payment = Payment.create!(order: @order, amount_cents: @order.total_cents,
          description: order_description, status: "open")
      end
    end

    @checkout_payment = payment
    checkout_url = payment.resume_mollie_checkout!

    if payment.paid?
      return redirect_to submitted_order_path(@order), notice: "This order has already been paid."
    end

    if checkout_url.blank?
      if payment.mollie_payment_id.present?
        if payment.status.in?(Payment::RETRYABLE_MOLLIE_STATUSES)
          return redirect_to submitted_order_path(@order), notice: "Your payment is being processed."
        end
        @order.with_lock do
          OrderRepricingService.call(order: @order, date: Date.current)
          payment = Payment.create!(order: @order, amount_cents: @order.total_cents,
            description: order_description, status: "open")
        end
        @checkout_payment = payment
      end

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
