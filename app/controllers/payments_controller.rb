class PaymentsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create, :success, :webhook]
  skip_before_action :verify_authenticity_token, only: [:webhook]

  before_action :load_participant, only: [:new, :create]

  def new
    existing = @participant.payments.pending_or_open.last
    @payment = existing || build_payment_for(@participant)
  end

  def create
    existing = @participant.payments.completed.last
    return redirect_to payments_success_path, notice: "Your registration has already been paid." if existing

    pricing = CongressPassPricing.new(attendance_option: @participant.attendance_option)
    @payment = @participant.payments.build(
      amount_cents: pricing.price_cents,
      description: pricing.description,
      status: "open"
    )

    unless @payment.save
      render :new, status: :unprocessable_entity and return
    end

    mollie_payment = Mollie::Payment.create(
      amount: { value: format("%.2f", @payment.amount_eur), currency: "EUR" },
      description: @payment.description,
      redirect_url: payments_success_url(payment_id: @payment.id),
      webhook_url: payments_webhook_url,
      metadata: { payment_id: @payment.id, participant_id: @participant.id }
    )

    @payment.update!(mollie_payment_id: mollie_payment.id)

    redirect_to mollie_payment.checkout_url, allow_other_host: true
  rescue Mollie::Exception => e
    @payment&.destroy
    flash.now[:alert] = "Payment could not be started: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def success
    @payment = Payment.find_by(id: params[:payment_id])

    if @payment&.mollie_payment_id.present?
      mollie_payment = Mollie::Payment.get(@payment.mollie_payment_id)
      @payment.update!(status: mollie_payment.status)
    end
  end

  def webhook
    mollie_payment = Mollie::Payment.get(params[:id])
    payment = Payment.find_by(mollie_payment_id: mollie_payment.id)

    if payment
      payment.update!(status: mollie_payment.status)
    end

    head :ok
  rescue Mollie::Exception => e
    Rails.logger.error "[Mollie] Webhook error for payment #{params[:id]}: #{e.message}"
    head :ok
  end

  private

  def load_participant
    @participant = Participant.find(params[:participant_id])
  end

  def build_payment_for(participant)
    pricing = CongressPassPricing.new(attendance_option: participant.attendance_option)
    participant.payments.build(
      amount_cents: pricing.price_cents,
      description: pricing.description,
      status: "open"
    )
  end
end
