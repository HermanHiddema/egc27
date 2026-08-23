class Admin::PaymentsController < ApplicationController
  before_action :require_admin!
  before_action :set_participant
  before_action :require_player_participant!, only: [:new, :create]
  before_action :set_payment, only: [:edit, :update]
  before_action :require_manual_payment, only: [:edit, :update]

  def new
    @payment = @participant.payments.build(default_payment_attributes)
  end

  def create
    if @participant.payments.where(provider: "mollie").merge(Payment.pending_or_open).exists?
      redirect_to new_admin_participant_payment_path(@participant),
        alert: "This participant has an outstanding Mollie payment. Cancel it in Mollie before recording a manual payment."
      return
    end

    @payment = @participant.payments.build(payment_params)
    # Manually recorded payments never belong to a Mollie transaction, and are
    # only recorded once the money has actually been received.
    @payment.provider = "manual"
    @payment.mollie_payment_id = nil
    @payment.status = "paid"

    if @payment.save
      redirect_to admin_participants_path, notice: "Payment was successfully recorded."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @payment.update(payment_params)
      redirect_to admin_participants_path, notice: "Payment was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

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
      amount_cents: pricing.price_cents,
      description: pricing.description,
      provider: "manual",
      payment_method: "bank_transfer",
      status: "paid"
    }
  rescue KeyError
    { provider: "manual", payment_method: "bank_transfer", status: "paid" }
  end

  def payment_params
    # The status can only be changed when correcting an existing payment; new
    # payments are always recorded as paid.
    attributes = [:amount_eur, :description, :payment_method, :reference]
    attributes << :status if action_name == "update"
    permitted = params.require(:payment).permit(*attributes)
    amount_eur = permitted.delete(:amount_eur)
    amount_cents = begin
      (amount_eur.to_s.tr(",", ".").to_d * 100).round
    rescue ArgumentError
      nil
    end
    permitted.merge(amount_cents: amount_cents)
  end
end
