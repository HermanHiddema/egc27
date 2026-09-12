# == Schema Information
#
# Table name: payments
#
#  id                       :bigint           not null, primary key
#  amount_cents             :integer          not null
#  confirmation_sent        :boolean          default(FALSE), not null
#  description              :string           not null
#  payment_method           :string
#  processed_in_bookkeeping :boolean          default(FALSE), not null
#  provider                 :string           default("mollie"), not null
#  reference                :string
#  status                   :string           default("open"), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  mollie_payment_id        :string
#  participant_id           :bigint           not null
#
# Indexes
#
#  index_payments_on_mollie_payment_id         (mollie_payment_id) UNIQUE
#  index_payments_on_participant_id            (participant_id)
#  index_payments_on_processed_in_bookkeeping  (processed_in_bookkeeping)
#  index_payments_on_provider                  (provider)
#  index_payments_on_status                    (status)
#
# Foreign Keys
#
#  fk_rails_...  (participant_id => participants.id)
#
class Payment < ApplicationRecord
  # "refunded" is not reported by Mollie as a payment status (Mollie keeps a
  # refunded payment as "paid" and reports the refunded amount separately), but
  # is recorded as a status of our own so refunds are visible everywhere a
  # payment status is used.
  STATUSES = %w[open canceled pending authorized expired failed paid refunded].freeze
  # Payments in these statuses can never succeed anymore, so they do not stand
  # in the way of recording a new (manual) payment. A refunded payment is
  # included because the money was returned to the payer, so the participant may
  # pay again.
  UNSUCCESSFUL_STATUSES = %w[canceled expired failed refunded].freeze
  # Payments are normally handled by Mollie, but admins can also record payments
  # that were received outside of Mollie (e.g. cash or bank transfer).
  PROVIDERS = %w[mollie manual].freeze
  # The method used to pay. Mollie reports its own methods (ideal, creditcard,
  # …), so only the methods available for manually recorded payments are listed.
  # "pointofsale" covers card payments taken in person at the congress desk.
  MANUAL_PAYMENT_METHODS = %w[cash pointofsale bank_transfer paypal other].freeze
  # Labels for methods that do not read well when humanized.
  PAYMENT_METHOD_LABELS = { "pointofsale" => "Point of sale", "paypal" => "PayPal" }.freeze
  # Mollie statuses from which a checkout can still be completed, so its
  # checkout URL can be reused instead of starting a new payment attempt.
  RETRYABLE_MOLLIE_STATUSES = %w[open pending authorized].freeze

  has_paper_trail

  belongs_to :participant

  validates :status, inclusion: { in: STATUSES }
  validates :provider, inclusion: { in: PROVIDERS }
  validates :payment_method, inclusion: { in: MANUAL_PAYMENT_METHODS }, if: :manual?
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :description, presence: true
  validates :mollie_payment_id, absence: true, if: :manual?
  validates :mollie_payment_id, uniqueness: true, allow_nil: true

  scope :completed, -> { where(status: "paid") }
  scope :refunded, -> { where(status: "refunded") }
  scope :pending_or_open, -> { where(status: %w[open pending authorized]) }
  scope :manual, -> { where(provider: "manual") }
  scope :unsuccessful, -> { where(status: UNSUCCESSFUL_STATUSES) }
  scope :blocking, -> { where.not(status: UNSUCCESSFUL_STATUSES) }
  scope :processed, -> { where(processed_in_bookkeeping: true) }
  scope :unprocessed, -> { where(processed_in_bookkeeping: false) }

  # Payments recorded manually by an admin can be created directly as paid, so
  # confirmations are sent both on create and on update.
  after_commit :send_payment_confirmation, on: [:create, :update], if: :became_paid?

  def self.payment_method_label(payment_method)
    return if payment_method.blank?

    PAYMENT_METHOD_LABELS.fetch(payment_method) { payment_method.humanize }
  end

  # Builds an unsaved payment for the current price of the participant's
  # congress pass.
  def self.build_for(participant)
    pricing = CongressPassPricing.new(
      attendance_option: participant.attendance_option,
      age_group: participant.age_group,
      participant_number: participant.participant_number
    )

    participant.payments.build(
      amount_cents: pricing.price_cents,
      description: pricing.description,
      status: "open"
    )
  end

  # Records the state of a Mollie payment reported through the webhook. Returns
  # the updated payment, or nil when the payment is unknown here.
  def self.sync_from_mollie_webhook(mollie_id)
    mollie_payment = Mollie::Payment.get(mollie_id)
    payment = find_by(mollie_payment_id: mollie_payment.id)
    payment&.sync_from_mollie!(mollie_payment)
    payment
  end

  def paid?
    status == "paid"
  end

  def refunded?
    status == "refunded"
  end

  def manual?
    provider == "manual"
  end

  def unsuccessful?
    UNSUCCESSFUL_STATUSES.include?(status)
  end

  def provider_label
    provider.humanize
  end

  def payment_method_label
    self.class.payment_method_label(payment_method)
  end

  def amount_eur
    amount_cents / 100.0
  end

  def amount_formatted
    "€ #{format('%.2f', amount_eur)}"
  end

  # The date until which the price of this payment is valid, or nil when it is
  # already in the final pricing period.
  def price_valid_until
    CongressPassPricing.new(
      attendance_option: participant.attendance_option,
      payment_date: created_at&.to_date || Date.current,
      age_group: participant.age_group
    ).current_tier_valid_until
  end

  # Fetches this payment at Mollie, or nil when it was never started there.
  def mollie_payment
    return if mollie_payment_id.blank?

    Mollie::Payment.get(mollie_payment_id)
  end

  # Mollie reports the method the payer actually used (ideal, creditcard, …)
  # once it is known, which is recorded alongside the status.
  def sync_from_mollie!(mollie_payment)
    update!(
      status: mollie_status(mollie_payment),
      payment_method: mollie_reported_payment_method(mollie_payment) || payment_method
    )
  end

  # Records the current state of this payment at Mollie. Returns the Mollie
  # payment, or nil when there is nothing to refresh.
  def refresh_from_mollie!
    mollie_payment.tap do |remote|
      sync_from_mollie!(remote) if remote&.status.present?
    end
  end

  # Like #refresh_from_mollie!, but logs errors instead of raising, for places
  # where an unreachable Mollie must not break the request.
  def refresh_from_mollie
    refresh_from_mollie!
  rescue Mollie::Exception => e
    Rails.logger.error "[Mollie] Error fetching payment status for #{mollie_payment_id}: #{e.message}"
    nil
  end

  # Refreshes this payment from Mollie and returns the checkout URL when the
  # checkout that was already started can still be completed. Returns nil when
  # there is no such checkout, so a new payment attempt is needed.
  def resume_mollie_checkout!
    remote_payment = refresh_from_mollie!

    return if remote_payment.blank? || remote_payment.checkout_url.blank?
    return unless RETRYABLE_MOLLIE_STATUSES.include?(remote_payment.status)

    remote_payment.checkout_url
  end

  # Starts a checkout at Mollie for this payment and returns its checkout URL.
  def start_mollie_checkout!(redirect_url:, webhook_url:)
    mollie_payment = Mollie::Payment.create(
      amount: { value: format("%.2f", amount_eur), currency: "EUR" },
      description: description,
      redirect_url: redirect_url,
      webhook_url: webhook_url,
      metadata: { payment_id: id, participant_id: participant_id }
    )

    raise Mollie::Exception, "No checkout URL was returned by Mollie." if mollie_payment.checkout_url.blank?

    update!(mollie_payment_id: mollie_payment.id) if mollie_payment_id.blank?

    mollie_payment.checkout_url
  end

  # Records a simulated Mollie status, used by the development-only simulation
  # controls so a payment flow can be exercised without calling Mollie.
  def simulate_mollie_status!(status)
    update!(status: status, mollie_payment_id: nil)
  end

  private

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
  def mollie_reported_payment_method(mollie_payment)
    attributes = mollie_payment.try(:attributes)
    return unless attributes.respond_to?(:[])

    (attributes["method"] || attributes[:method]).presence
  end

  def became_paid?
    saved_change_to_status? && paid?
  end

  def send_payment_confirmation
    return if participant.email.blank?

    # Atomic check-and-set prevents duplicate emails under concurrent webhook/redirect updates.
    return unless Payment.where(id: id, confirmation_sent: false).update_all(confirmation_sent: true) == 1

    ParticipantMailer.payment_confirmation(self).deliver_now
  rescue StandardError => e
    Rails.logger.error("Failed to deliver payment confirmation for Payment #{id}: #{e.class}: #{e.message}")
  end
end
