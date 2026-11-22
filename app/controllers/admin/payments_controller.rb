class Admin::PaymentsController < ApplicationController
  include EuropeanDateParameters
  SORT_COLUMNS = %w[id date order_id amount payer].freeze

  before_action :require_admin!
  before_action :set_participant, only: [:edit, :update]
  before_action :set_payment, only: [:edit, :update]
  before_action :require_manual_payment, only: [:edit, :update]
  before_action :set_participant_overview_params, only: [:edit, :update]

  def index
    @payment_methods = Payment.where.not(payment_method: [nil, ""]).distinct.order(:payment_method).pluck(:payment_method)
    @method_filter = permitted_method_filter
    @sort = permitted_sort
    @direction = permitted_direction

    payments = Payment.includes(:settlement, order: :user, products: :productable)
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
  end

  def show
    @payment = Payment.includes(:settlement, order: :user).find(params[:id])
    @order = @payment.order
    @refunds = @payment.refunds.includes(:settlement).order(created_at: :desc, id: :desc)
    @chargebacks = @payment.chargebacks.includes(:settlement).order(created_at: :desc, id: :desc)
  end

  def edit
  end

  def update
    @payment.assign_attributes(payment_params)
    @payment.status = "paid"

    if @payment.save
      redirect_to admin_participants_path(**@participant_overview_params), notice: "Payment was successfully updated."
    else
      add_european_date_errors(@payment)
      render :edit, status: :unprocessable_entity
    end
  end

  private

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

  def set_participant_overview_params
    @participant_overview_params = params.permit(:country, :type, :name, :sort, :direction, status: [], payment_status: []).to_h
  end

  def set_participant
    @participant = Participant.find_by!(uuid: params[:participant_id])
  end

  def set_payment
    @payment = @participant.payments.find(params[:id])
  end

  # Mollie owns the state of its own payments, so only manually recorded
  # payments can be edited here.
  def require_manual_payment
    return if @payment.manual?

    redirect_to admin_order_path(@payment.order),
      alert: "Payments made through Mollie cannot be edited."
  end

  def payment_params
    permitted = params.require(:payment).permit(:amount_eur, :description, :payment_method, :payment_date, :reference)
    amount_eur_input = permitted.delete(:amount_eur).to_s
    @amount_eur_input = amount_eur_input
    amount_eur_str = amount_eur_input.tr(",", ".")
    begin
      amount_cents = (BigDecimal(amount_eur_str) * 100).round
    rescue ArgumentError
      amount_cents = nil
    end
    normalize_european_dates(permitted.merge(amount_cents: amount_cents), dates: [:payment_date])
  end
end
