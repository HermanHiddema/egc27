class Admin::PaymentsController < ApplicationController
  before_action :require_admin!
  before_action :set_participant

  def new
    @payment = @participant.payments.build(default_payment_attributes)
  end

  def create
    @payment = @participant.payments.build(payment_params)
    @payment.mollie_payment_id = nil

    if @payment.payment_method == "mollie"
      @payment.errors.add(:payment_method, "must be a payment received outside of Mollie")
      render :new, status: :unprocessable_entity and return
    end

    if @payment.save
      redirect_to admin_participants_path, notice: "Payment was successfully recorded."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_participant
    @participant = Participant.find_by!(uuid: params[:participant_id])
  end

  def default_payment_attributes
    pricing = CongressPassPricing.new(
      attendance_option: @participant.attendance_option,
      age_group: @participant.age_group
    )

    {
      amount_cents: pricing.price_cents,
      description: pricing.description,
      payment_method: "bank_transfer",
      status: "paid"
    }
  rescue KeyError
    { payment_method: "bank_transfer", status: "paid" }
  end

  def payment_params
    permitted = params.require(:payment).permit(:amount_eur, :description, :payment_method, :status, :reference)
    amount_eur = permitted.delete(:amount_eur)
    permitted.merge(amount_cents: (amount_eur.to_s.tr(",", ".").to_d * 100).round)
  end
end
