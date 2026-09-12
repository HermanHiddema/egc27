class PaymentsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create, :success, :webhook]
  skip_before_action :verify_authenticity_token, only: [:webhook]

  before_action :load_participant, only: [:new, :create]
  before_action :require_player_participant, only: [:new, :create]
  before_action :require_confirmed_participant, only: [:create]

  def new
    @confirmed = @participant.confirmed?
    return unless @confirmed

    refresh_completed_payments_until_paid

    @payment = @participant.payments.completed.order(created_at: :desc).first || @participant.payments.pending_or_open.order(created_at: :desc).first || build_payment_for(@participant)
    @price_valid_until = CongressPassPricing.new(
      attendance_option: @participant.attendance_option,
      payment_date: (@payment.created_at&.to_date || Date.current),
      age_group: @participant.age_group
    ).current_tier_valid_until
    @show_simulation_controls = mollie_simulation_enabled?
  end

  def create
    @confirmed = @participant.confirmed?
    created_payment = false

    refresh_completed_payments_until_paid
    existing = @participant.payments.completed.order(created_at: :desc).first
    return redirect_to success_payments_path, notice: "Your registration has already been paid." if existing&.paid?

    @payment = @participant.payments.pending_or_open.order(created_at: :desc).first

    unless @payment
      @payment = build_payment_for(@participant)
      created_payment = true

      unless @payment.save
        render :new, status: :unprocessable_entity and return
      end
    end

    if simulate_mollie_payment?
      @payment.update!(status: params[:simulate_status], mollie_payment_id: nil)
      return redirect_to success_payments_path(payment_id: @payment.id),
        notice: "Simulated Mollie payment status: #{@payment.status}."
    end

    mollie_payment = @payment.mollie_payment_id.present? ? Mollie::Payment.get(@payment.mollie_payment_id) : nil

    if mollie_payment&.status.present?
      sync_from_mollie(@payment, mollie_payment)
    end

    if @payment.paid?
      return redirect_to success_payments_path, notice: "Your registration has already been paid."
    end

    if mollie_payment.nil?
      mollie_payment = create_mollie_payment_for(@payment)
    elsif mollie_payment.checkout_url.blank? || !retryable_mollie_status?(mollie_payment.status)
      @payment = build_payment_for(@participant)
      created_payment = true

      unless @payment.save
        render :new, status: :unprocessable_entity and return
      end

      mollie_payment = create_mollie_payment_for(@payment)
    end

    raise Mollie::Exception, "No checkout URL was returned by Mollie." if mollie_payment.checkout_url.blank?

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
        sync_from_mollie(@payment, mollie_payment)
      rescue Mollie::Exception => e
        Rails.logger.error "[Mollie] Error fetching payment status for #{@payment.mollie_payment_id}: #{e.message}"
      end
    end
  end

  def webhook
    mollie_payment = Mollie::Payment.get(params[:id])
    payment = Payment.find_by(mollie_payment_id: mollie_payment.id)

    if payment
      sync_from_mollie(payment, mollie_payment)
    end

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

  def build_payment_for(participant)
    pricing = CongressPassPricing.new(attendance_option: participant.attendance_option, age_group: participant.age_group, participant_number: participant.participant_number)
    participant.payments.build(
      amount_cents: pricing.price_cents,
      description: pricing.description,
      status: "open"
    )
  end

  def create_mollie_payment_for(payment)
    Mollie::Payment.create(
      amount: { value: format("%.2f", payment.amount_eur), currency: "EUR" },
      description: payment.description,
      redirect_url: success_payments_url(payment_id: payment.id),
      webhook_url: webhook_payments_url,
      metadata: { payment_id: payment.id, participant_id: payment.participant_id }
    )
  end

  # Mollie reports the method the payer actually used (ideal, creditcard, …)
  # once it is known, which is recorded alongside the status.
  def sync_from_mollie(payment, mollie_payment)
    payment.update!(
      status: mollie_status(mollie_payment),
      payment_method: mollie_payment_method(mollie_payment) || payment.payment_method
    )
  end

  # A refunded payment keeps the "paid" status at Mollie, which only reports the
  # refunded amount separately, so refunds are mapped onto our own "refunded"
  # status.
  def mollie_status(mollie_payment)
    return "refunded" if mollie_refunded?(mollie_payment)

    mollie_payment.status
  end

  def mollie_refunded?(mollie_payment)
    refunded_amount = mollie_amount_value(mollie_payment.try(:amount_refunded))
    refunded_amount&.positive?
  end

  def mollie_amount_value(amount)
    return if amount.blank?

    value = if amount.respond_to?(:value)
      amount.value
    elsif amount.respond_to?(:[])
      amount["value"] || amount[:value]
    end

    return if value.blank?

    BigDecimal(value.to_s)
  end

  # Read from the raw Mollie attributes because `method` is also the name of a
  # standard Ruby method, which makes the generated reader unreliable.
  def mollie_payment_method(mollie_payment)
    attributes = mollie_payment.try(:attributes)
    return unless attributes.respond_to?(:[])

    (attributes["method"] || attributes[:method]).presence
  end

  def retryable_mollie_status?(status)
    %w[open pending authorized].include?(status)
  end

  def refresh_completed_payments_until_paid
    @participant.payments.completed.order(created_at: :desc).each do |payment|
      break if payment.mollie_payment_id.blank?

      sync_from_mollie(payment, Mollie::Payment.get(payment.mollie_payment_id))
      break if payment.paid?
    end

    @participant.association(:payments).reset
  rescue Mollie::Exception => e
    Rails.logger.error "[Mollie] Error refreshing paid payment #{payment&.mollie_payment_id}: #{e.message}"
  end

  def simulate_mollie_payment?
    mollie_simulation_enabled? && params[:simulate_status].in?(Payment::STATUSES)
  end

  def mollie_simulation_enabled?
    Rails.application.config.x.payments.simulate_mollie && (Rails.env.development? || Rails.env.test?)
  end
end
