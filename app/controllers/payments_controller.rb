class PaymentsController < ApplicationController
  ALREADY_PAID_NOTICE = "Your registration has already been paid.".freeze

  skip_before_action :authenticate_user!, only: [:new, :create, :success, :webhook]
  skip_before_action :verify_authenticity_token, only: [:webhook]

  before_action :load_participant, only: [:new, :create]
  before_action :require_player_participant, only: [:new, :create]
  before_action :require_participant_owner, only: [:new, :create]

  def new
    redirect_to participant_order_path(@participant)
  end

  def create
    redirect_to participant_order_path(@participant), notice: "Payments are managed from your Order."
  end

  # The payment is looked up by a signed, expiring token handed out only to the
  # payer, so payments cannot be enumerated through this public page.
  def success
    @payment = Payment.find_by_return_token(params[:token])
    @payment&.refresh_from_mollie
  end

  def webhook
    Payment.sync_from_mollie_webhook(params[:id])

    head :ok
  rescue Mollie::Exception => e
    Rails.logger.error "[Mollie] Webhook error for payment #{params[:id]}: #{e.message}"
    head :service_unavailable
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

  def require_participant_owner
    return authenticate_user! unless user_signed_in?
    return if @participant.user_id == current_user.id

    head :not_found
  end

  def participant_order_path(participant)
    order = participant.current_order
    return order_path if order.nil? || order.draft?

    submitted_order_path(order)
  end

  def start_new_payment_attempt
    order = @participant.current_order
    order.submit! if order.draft?
    order.with_lock do
      return order.payments.completed.order(created_at: :desc).first if order.closed?

      OrderRepricingService.call(order:, date: Date.current)
      Payment.build_for(@participant).tap do |payment|
        payment.save!
        @started_payment_attempt = payment
      end
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
