class PaymentsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create, :success, :webhook]
  skip_before_action :verify_authenticity_token, only: [:webhook]

  before_action :load_participant, only: [:new, :create]
  before_action :require_player_participant, only: [:new, :create]
  before_action :require_confirmed_participant, only: [:create]

  def new
    @confirmed = @participant.confirmed?
    return unless @confirmed

    @payment = @participant.payments.completed.order(created_at: :desc).first || build_payment_for(@participant)
  end

  def create
    @confirmed = @participant.confirmed?
    created_payment = false

    existing = @participant.payments.completed.order(created_at: :desc).first
    return redirect_to success_payments_path, notice: "Your registration has already been paid." if existing

    @payment = @participant.payments.pending_or_open.order(created_at: :desc).first

    unless @payment
      @payment = build_payment_for(@participant)
      created_payment = true

      unless @payment.save
        render :new, status: :unprocessable_entity and return
      end
    end

    mollie_payment = if @payment.mollie_payment_id.present?
      Mollie::Payment.get(@payment.mollie_payment_id)
    else
      Mollie::Payment.create(
        amount: { value: format("%.2f", @payment.amount_eur), currency: "EUR" },
        description: @payment.description,
        redirect_url: success_payments_url(payment_id: @payment.id),
        webhook_url: webhook_payments_url,
        metadata: { payment_id: @payment.id, participant_id: @participant.id }
      )
    end

    @payment.update!(mollie_payment_id: mollie_payment.id) if @payment.mollie_payment_id.blank?

    redirect_to mollie_payment.checkout_url, allow_other_host: true
  rescue Mollie::Exception => e
    if created_payment && @payment&.persisted? && @payment.mollie_payment_id.blank?
      @payment.destroy
      @payment = build_payment_for(@participant)
    end
    flash.now[:alert] = "Payment could not be started: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def success
    @payment = Payment.find_by(id: params[:payment_id])

    if @payment&.mollie_payment_id.present?
      begin
        mollie_payment = Mollie::Payment.get(@payment.mollie_payment_id)
        @payment.update!(status: mollie_payment.status)
      rescue Mollie::Exception => e
        Rails.logger.error "[Mollie] Error fetching payment status for #{@payment.mollie_payment_id}: #{e.message}"
      end
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

  def require_player_participant
    unless @participant.player?
      redirect_to participant_path(@participant), notice: "No payment is required for visitor registrations."
    end
  end

  def require_confirmed_participant
    unless @participant.confirmed?
      redirect_to new_participant_payment_path(@participant),
        alert: "Please confirm your email address before completing payment."
    end
  end

  def build_payment_for(participant)
    pricing = CongressPassPricing.new(attendance_option: participant.attendance_option, age_group: participant.age_group)
    participant.payments.build(
      amount_cents: pricing.price_cents,
      description: pricing.description,
      status: "open"
    )
  end
end
