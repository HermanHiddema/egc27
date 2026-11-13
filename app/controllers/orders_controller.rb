class OrdersController < ApplicationController
  before_action :set_draft_order, only: [:show, :new_participant, :add_participant, :edit_product, :update_product, :remove_product, :empty, :submit, :cancel]
  before_action :set_submitted_order, only: [:show_submitted, :pay_submitted]

  def show
    @requires_confirmation = ticket_products? && !current_user.confirmed?
    OrderRepricingService.call(order: @order, date: Date.current) if @order.draft? && !@requires_confirmation
    @products = @order.products.includes(:productable)
    @show_simulation_controls = mollie_simulation_enabled? && !@order.closed? && !@requires_confirmation
  end

  def index
    @orders = current_user.orders.submitted.includes(:products, :payments).order(created_at: :desc, id: :desc)
    @show_simulation_controls = mollie_simulation_enabled?
  end

  def new_participant
    @participants = current_user.participants.includes(:participant_tickets).order(:last_name, :first_name)
    @retryable_participants = @participants.select do |participant|
      participant.draft_ticket.nil? && participant.retryable_ticket.present?
    end
    @eligible_participants = @participants.select do |participant|
      participant.draft_ticket.nil? && participant.retryable_ticket.nil? && participant.can_purchase_ticket?
    end
  end

  def show_submitted
    @products = @order.products_for_display
    @latest_payment = @order.payments.order(created_at: :desc, id: :desc).first
    @payments = @order.payments.order(created_at: :desc, id: :desc)
    @show_simulation_controls = mollie_simulation_enabled? && !@order.closed? && !active_payment?
    render :show
  end

  def add_participant
    participant = current_user.participants.find_by!(uuid: params[:participant_id])
    if participant.draft_ticket&.product&.order&.draft?
      return redirect_to order_path, notice: "This participant already has a ticket in your shopping basket."
    end
    if participant.retryable_ticket.present? && participant.retryable_ticket.order.submitted?
      return redirect_to submitted_order_path(participant.retryable_ticket.order),
        notice: "Please pay Order #{participant.retryable_ticket.order.id} to complete payment for this participant."
    end
    @order.with_lock do
      participant.add_ticket_to_draft_order!
      redirect_to order_path, notice: "Ticket added to your shopping basket."
    end
  rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid => e
    redirect_to order_path, alert: e.message
  end

  def edit_product
    @product = @order.products.includes(:productable).find(params[:product_id])
    return head :not_found unless @product.productable.is_a?(ParticipantTicket)

    @participant = @product.productable.participant
    head :not_found unless @participant.user_id == current_user.id
  end

  def update_product
    product = @order.products.includes(:productable).find(params[:product_id])
    return head :not_found unless product.productable.is_a?(ParticipantTicket)

    participant = product.productable.participant
    return head :not_found unless participant.user_id == current_user.id

    attrs = if participant.valid_admission?
      params.require(:participant).permit(:gender, :country, :club, :image_use_consent)
    else
      params.require(:participant).permit(:first_name, :last_name, :gender, :age_group, :country, :club,
        :image_use_consent, :attendance_option, :rank, :egd_pin, :phone)
    end

    updated = @order.with_lock do
      participant.update(attrs).tap do |saved|
        OrderRepricingService.call(order: @order, date: Date.current) if saved
      end
    end

    if updated
      redirect_to order_path, notice: "Ticket details updated."
    else
      @product = product
      @participant = participant
      render :edit_product, status: :unprocessable_entity
    end
  end

  def remove_product
    @order.with_lock do
      product = @order.products.includes(:productable).find(params[:product_id])
      productable = product.productable
      product.destroy!
      productable.destroy! if productable.is_a?(ParticipantTicket) || productable.is_a?(HostelBooking)
    end
    redirect_to order_path, notice: "Item removed from your shopping basket."
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordNotSaved => e
    redirect_to order_path, alert: e.message
  end

  def empty
    @order.with_lock do
      @order.products.includes(:productable).each do |product|
        productable = product.productable
        product.destroy!
        productable.destroy! if productable.is_a?(ParticipantTicket) || productable.is_a?(HostelBooking)
      end
    end
    redirect_to order_path, notice: "Your shopping basket is empty."
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordNotSaved => e
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

    old_total = params[:confirmed_total_cents].to_i
    @order.with_lock do
      OrderRepricingService.call(order: @order, date: Date.current)
      if old_total != @order.total_cents
        return redirect_to order_path, alert: "Ticket prices changed. Please review the updated total and confirm checkout again."
      end
      @order.submit! if @order.draft?
      create_payment_for_order! unless @order.payments.pending_or_open.exists?
    end
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
    return redirect_to submitted_order_path(@order), notice: "Your payment is already being processed." if active_payment?
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

  def active_payment?
    @order.payments.pending_or_open.exists?
  end

  def create_payment_for_order!
    return if @order.closed? || active_payment?

    Payment.create!(order: @order, amount_cents: @order.total_cents, description: order_description, status: "open")
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
