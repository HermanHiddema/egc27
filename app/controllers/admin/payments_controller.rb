class Admin::PaymentsController < ApplicationController
  PROCESSED_FILTERS = %w[processed unprocessed].freeze
  SORT_COLUMNS = %w[id date order_id amount payer].freeze

  before_action :require_admin!
  before_action :set_participant, except: [:index, :show, :mark_processed, :unmark_processed]
  before_action :require_player_participant!, only: [:new, :create, :add_ticket]
  before_action :set_payment, only: [:edit, :update]
  before_action :require_manual_payment, only: [:edit, :update]

  # List every payment attempt; bookkeeping filters remain limited to completed
  # payments so failed or pending attempts cannot be marked as processed.
  def index
    @processed_filter = permitted_processed_filter
    @payment_methods = Payment.where.not(payment_method: [nil, ""]).distinct.order(:payment_method).pluck(:payment_method)
    @method_filter = permitted_method_filter
    @sort = permitted_sort
    @direction = permitted_direction

    payments = Payment.includes(:settlement, order: :user, products: :productable)
    if @processed_filter == "processed"
      payments = payments.for_bookkeeping.processed
    elsif @processed_filter == "unprocessed"
      payments = payments.for_bookkeeping.unprocessed
    end
    payments = payments.where(payment_method: [nil, ""]) if @method_filter == "blank"
    payments = payments.where(payment_method: @method_filter) if @method_filter.present? && @method_filter != "blank"

    order_expression = case @sort
    when "id" then Payment.arel_table[:id]
    when "order_id" then Order.arel_table[:id]
    when "amount" then Payment.arel_table[:amount_cents]
    when "payer" then Arel.sql("COALESCE(NULLIF(users.full_name, ''), users.email)")
    else Arel.sql("COALESCE(payments.payment_date, payments.created_at::date)")
    end
    ordering = @direction == :asc ? order_expression.asc : order_expression.desc
    tie_breakers = []
    if @sort == "date"
      created_at_order = @direction == :asc ? Payment.arel_table[:created_at].asc : Payment.arel_table[:created_at].desc
      tie_breakers << created_at_order
    end
    tie_breakers << Payment.arel_table[:id].desc
    @payments = payments.joins(order: :user)
      .order(ordering.nulls_last, *tie_breakers)
    @unprocessed_count = Payment.for_bookkeeping.unprocessed.count
  end

  def show
    @payment = Payment.includes(:settlement, :refunds, :chargebacks, order: [:user, :products]).find(params[:id])
    @order = @payment.order
    @products = @order.products_for_display
    @refunds = @payment.refunds.includes(:settlement).order(created_at: :desc, id: :desc)
    @chargebacks = @payment.chargebacks.includes(:settlement).order(created_at: :desc, id: :desc)
  end

  def mark_processed
    update_processed_in_bookkeeping(true, "Payment was marked as processed in the bookkeeping.")
  end

  # Marking a payment is a single click, so it must be reversible when an admin
  # marks the wrong payment.
  def unmark_processed
    update_processed_in_bookkeeping(false, "Payment was marked as not processed in the bookkeeping.")
  end

  def new
    @order = @participant.current_order
    OrderRepricingService.call(order: @order, date: Date.current) if @order
    @payment = @order.payments.build(default_payment_attributes) if @order
  end

  def create
    @order = @participant.current_order
    unless @order
      redirect_to new_admin_participant_payment_path(@participant),
        alert: "Add a ticket to this participant's draft order before recording a payment."
      return
    end

    if @participant.payments.where(provider: "mollie").merge(Payment.pending_or_open).exists?
      redirect_to new_admin_participant_payment_path(@participant),
        alert: "This participant has an outstanding Mollie payment. Cancel it in Mollie before recording a manual payment."
      return
    end

    validating_payment = false
    begin
      ActiveRecord::Base.transaction do
        @order.submit! if @order.draft?
        @payment = @order.payments.build(payment_params)
        # Manually recorded payments never belong to a Mollie transaction, and
        # are only recorded once the money has actually been received.
        @payment.provider = "manual"
        @payment.mollie_payment_id = nil
        @payment.status = "paid"
        validating_payment = true
        @payment.save!
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      if validating_payment
        @payment = e.record
        @order.reload
        render :new, status: :unprocessable_entity
      else
        redirect_to edit_admin_participant_path(@participant), alert: e.record.errors.full_messages.to_sentence
      end
      return
    end

    redirect_to admin_participants_path, notice: "Payment was successfully recorded."
  end

  def add_ticket
    @participant.add_ticket_to_draft_order!
    redirect_to new_admin_participant_payment_path(@participant), notice: "A ticket was added to the participant's draft order."
  rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid => e
    redirect_to new_admin_participant_payment_path(@participant), alert: e.message
  end

  def edit
  end

  def update
    @payment.assign_attributes(payment_params)
    @payment.status = "paid"

    if @payment.save
      redirect_to admin_participants_path, notice: "Payment was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def update_processed_in_bookkeeping(processed, notice)
    payment = Payment.for_bookkeeping.find(params[:id])
    payment.update!(processed_in_bookkeeping: processed)

    redirect_to admin_payments_path(processed: permitted_processed_filter), notice: notice
  end

  def permitted_processed_filter
    PROCESSED_FILTERS.include?(params[:processed]) ? params[:processed] : nil
  end

  def permitted_method_filter
    return "blank" if params[:method] == "blank"

    @payment_methods.include?(params[:method]) ? params[:method] : nil
  end

  def permitted_sort
    SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : "date"
  end

  def permitted_direction
    params[:direction] == "asc" ? :asc : :desc
  end

  def set_participant
    @participant = Participant.find_by!(uuid: params[:participant_id])
  end

  def set_payment
    @payment = @participant.payments.find(params[:id])
  end

  # Visitors pay nothing, so recording a manual payment for them is disallowed.
  def require_player_participant!
    return if @participant.player?

    redirect_to admin_participants_path,
      alert: "Manual payments can only be recorded for player participants."
  end

  # Mollie owns the state of its own payments, so only manually recorded
  # payments can be edited here.
  def require_manual_payment
    return if @payment.manual?

    redirect_to new_admin_participant_payment_path(@participant),
      alert: "Payments made through Mollie cannot be edited."
  end

  def default_payment_attributes
    pricing = CongressPassPricing.new(
      attendance_option: @participant.attendance_option,
      age_group: @participant.age_group
    )

    {
      amount_cents: @order.total_cents,
      description: pricing.description,
      provider: "manual",
      payment_method: "bank_transfer",
      payment_date: Date.current,
      status: "paid",
      processed_in_bookkeeping: true
    }
  rescue KeyError
    { provider: "manual", payment_method: "bank_transfer", payment_date: Date.current, status: "paid", processed_in_bookkeeping: true }
  end

  def payment_params
    permitted = params.require(:payment).permit(:amount_eur, :description, :payment_method, :payment_date, :reference, :processed_in_bookkeeping)
    amount_eur_input = permitted.delete(:amount_eur).to_s
    @amount_eur_input = amount_eur_input
    amount_eur_str = amount_eur_input.tr(",", ".")
    begin
      amount_cents = (BigDecimal(amount_eur_str) * 100).round
    rescue ArgumentError
      amount_cents = nil
    end
    permitted.merge(amount_cents: amount_cents)
  end
end
