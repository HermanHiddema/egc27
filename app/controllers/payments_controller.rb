class PaymentsController < ApplicationController
  ALREADY_PAID_NOTICE = "Your registration has already been paid.".freeze

  skip_before_action :authenticate_user!, only: [:new, :create, :success, :webhook]
  skip_before_action :verify_authenticity_token, only: [:webhook]

  before_action :load_participant, only: [:new, :create]
  before_action :require_player_participant, only: [:new, :create]
  before_action :require_confirmed_participant, only: [:create]

  def new
    @confirmed = @participant.confirmed?
    return unless @confirmed

    @participant.refresh_paid_payments!

    @payment = @participant.current_payment
    @price_valid_until = @payment.price_valid_until
    @show_simulation_controls = mollie_simulation_enabled?
  end

  def create
    @confirmed = @participant.confirmed?

    @participant.refresh_paid_payments!
    return redirect_to success_payments_path, notice: ALREADY_PAID_NOTICE if @participant.paid_payment.present?

    @payment = @participant.pending_payment || start_new_payment_attempt

    if simulate_mollie_payment?
      @payment.simulate_mollie_status!(params[:simulate_status])
      return redirect_to success_payments_path(payment_id: @payment.id),
        notice: "Simulated Mollie payment status: #{@payment.status}."
    end

    checkout_url = @payment.resume_mollie_checkout!
    return redirect_to success_payments_path, notice: ALREADY_PAID_NOTICE if @payment.paid?

    if checkout_url.blank?
      # A Mollie payment that cannot be completed anymore is replaced by a new
      # payment attempt, because Mollie owns the state of its own payments.
      @payment = start_new_payment_attempt if @payment.mollie_payment_id.present?
      checkout_url = @payment.start_mollie_checkout!(
        redirect_url: success_payments_url(payment_id: @payment.id),
        webhook_url: webhook_payments_url
      )
    end

    redirect_to checkout_url, allow_other_host: true
  rescue ActiveRecord::RecordInvalid => e
    @payment = e.record
    render :new, status: :unprocessable_entity
  rescue Mollie::Exception => e
    discard_unstarted_payment_attempt
    flash.now[:alert] = "Payment could not be started: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def success
    @payment = Payment.find_by(id: params[:payment_id])
    @payment&.refresh_from_mollie
  end

  def webhook
    Payment.sync_from_mollie_webhook(params[:id])

    head :ok
  rescue Mollie::Exception => e
    Rails.logger.error "[Mollie] Webhook error for payment #{params[:id]}: #{e.message}"
    head :ok
  end

  private

  def load_participant
    @participant = Participant.find_by!(uuid: params[:participant_id])
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

  def start_new_payment_attempt
    Payment.build_for(@participant).tap do |payment|
      payment.save!
      @started_payment_attempt = payment
    end
  end

  # A payment attempt created in this request that never reached Mollie leaves
  # no trace there, so it is removed again and replaced by a fresh unsaved
  # payment for the retry offered on the page.
  def discard_unstarted_payment_attempt
    return unless @started_payment_attempt&.persisted?
    return if @started_payment_attempt.mollie_payment_id.present?

    @started_payment_attempt.destroy
    @payment = Payment.build_for(@participant) if @payment == @started_payment_attempt
  end

  def simulate_mollie_payment?
    mollie_simulation_enabled? && params[:simulate_status].in?(Payment::STATUSES)
  end

  def mollie_simulation_enabled?
    Rails.application.config.x.payments.simulate_mollie && (Rails.env.development? || Rails.env.test?)
  end
end
