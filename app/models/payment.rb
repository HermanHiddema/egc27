# == Schema Information
#
# Table name: payments
#
#  id                        :bigint           not null, primary key
#  amount_cents              :integer          not null
#  amount_charged_back_cents :integer          default(0)
#  amount_refunded_cents     :integer          default(0)
#  confirmation_sent         :boolean          default(FALSE), not null
#  description               :string           not null
#  payment_date              :date
#  payment_method            :string
#  processed_in_bookkeeping  :boolean          default(FALSE), not null
#  provider                  :string           default("mollie"), not null
#  reference                 :string
#  status                    :string           default("open"), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  mollie_payment_id         :string
#  order_id                  :bigint           not null
#  settlement_id             :bigint
#
# Indexes
#
#  index_payments_on_mollie_payment_id         (mollie_payment_id) UNIQUE
#  index_payments_on_order_id                  (order_id)
#  index_payments_on_processed_in_bookkeeping  (processed_in_bookkeeping)
#  index_payments_on_provider                  (provider)
#  index_payments_on_settlement_id             (settlement_id)
#  index_payments_on_status                    (status)
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id)
#  fk_rails_...  (settlement_id => settlements.id)
#
class Payment < ApplicationRecord
  STATUSES = %w[open canceled pending authorized expired failed paid].freeze
  UNSUCCESSFUL_STATUSES = %w[canceled expired failed].freeze
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
  # How long the token in the return URL after a checkout stays valid.
  RETURN_TOKEN_EXPIRY = 1.week

  has_paper_trail

  belongs_to :order
  has_many :products, through: :order
  has_many :participant_tickets, through: :products, source: :productable, source_type: "ParticipantTicket"
  has_many :participants, through: :participant_tickets
  has_many :hostel_bookings, through: :products, source: :productable, source_type: "HostelBooking"
  # The Mollie payout this payment was paid out in, once Mollie settled it.
  belongs_to :settlement, optional: true
  has_many :refunds, dependent: :nullify
  has_many :chargebacks, dependent: :nullify

  validates :status, inclusion: { in: STATUSES }
  validates :provider, inclusion: { in: PROVIDERS }
  validates :payment_method, inclusion: { in: MANUAL_PAYMENT_METHODS }, if: :manual?
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validate :covers_full_order_amount, if: :will_save_change_to_amount_cents?
  validate :order_is_submitted
  validates :amount_refunded_cents, :amount_charged_back_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :description, presence: true
  validates :mollie_payment_id, absence: true, if: :manual?
  validates :mollie_payment_id, uniqueness: true, allow_nil: true
  validates :payment_date, presence: true, if: :manual?
  validate :paid_status_is_final, on: :update

  scope :completed, -> { where(status: "paid") }
  # NULL denotes a legacy reversal whose amount is unknown.
  scope :refunded, -> { where("amount_refunded_cents IS NULL OR amount_refunded_cents > 0") }
  scope :charged_back, -> { where("amount_charged_back_cents IS NULL OR amount_charged_back_cents > 0") }
  scope :reversed, -> { refunded.or(charged_back) }
  scope :unreversed, -> { where(amount_refunded_cents: 0, amount_charged_back_cents: 0) }
  scope :for_bookkeeping, -> { completed }
  scope :pending_or_open, -> { where(status: %w[open pending authorized]) }
  scope :manual, -> { where(provider: "manual") }
  scope :unsuccessful, -> { where(status: UNSUCCESSFUL_STATUSES) }
  scope :blocking, -> { where.not(status: UNSUCCESSFUL_STATUSES) }
  scope :processed, -> { where(processed_in_bookkeeping: true) }
  scope :unprocessed, -> { where(processed_in_bookkeeping: false) }

  # Mollie payments get their payment date once they become paid.
  before_save :set_mollie_payment_date, if: :needs_mollie_payment_date?
  around_save :with_order_lock
  before_create :prevent_creation_on_closed_order
  before_update :prevent_reopening_paid_payment
  after_commit :reprice_order_after_terminal_attempt, on: :update

  # Payments recorded manually by an admin can be created directly as paid, so
  # confirmations are sent both on create and on update.
  after_commit :send_payment_confirmation, on: [:create, :update], if: :became_paid?

  def self.payment_method_label(payment_method)
    return if payment_method.blank?

    PAYMENT_METHOD_LABELS.fetch(payment_method) { payment_method.humanize }
  end

  # Builds an unsaved payment for the stored Product price.
  def self.build_for(participant)
    order = participant.order
    pricing = CongressPassPricing.new(
      attendance_option: participant.attendance_option,
      age_group: participant.age_group,
      participant_number: participant.participant_number
    )

    description = if order.products.count == 1
      pricing.description
    else
      "EGC 2027 order (#{order.products.count} items)"
    end

    order.payments.build(
      amount_cents: order.total_cents,
      description:,
      status: "open"
    )
  end

  # Reprices the order before building a full-order payment for a hostel booking.
  def self.build_for_hostel_booking(hostel_booking)
    OrderRepricingService.call(order: hostel_booking.order, date: Date.current)

    new(
      order: hostel_booking.order,
      amount_cents: hostel_booking.order.total_cents,
      description: hostel_booking.description,
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

  # Finds the payment for a token created by #return_token, or nil when the
  # token is missing, tampered with or expired.
  def self.find_by_return_token(token)
    return if token.blank?

    find_signed(token.to_s, purpose: :payment_return)
  end

  # A signed, expiring token identifying this payment, used in the URL the payer
  # returns to after a checkout instead of the guessable numeric id.
  def return_token
    signed_id(purpose: :payment_return, expires_in: RETURN_TOKEN_EXPIRY)
  end

  # Compatibility readers for the current single-product order.
  def participant
    participants.first
  end

  def hostel_booking
    hostel_bookings.first
  end

  def participant_id
    participant&.id
  end

  def hostel_booking_id
    hostel_booking&.id
  end

  def payee_label
    labels = participants.map do |participant|
      "#{participant.first_name} #{participant.last_name} (#{participant.participant_number})"
    end
    labels.concat(hostel_bookings.map { |booking| "Hostel booking ##{booking.id}" })
    labels.join(", ")
  end

  def participant=(participant)
    self.order = participant&.order
  end

  def hostel_booking=(booking)
    self.order = booking&.order
  end

  def paid?
    status == "paid"
  end

  def payable?
    !paid?
  end

  def refunded?
    amount_refunded_cents.nil? || amount_refunded_cents.positive?
  end

  def charged_back?
    amount_charged_back_cents.nil? || amount_charged_back_cents.positive?
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
  #
  # A payment that becomes charged back is flagged as not processed in the
  # bookkeeping again, so admins notice it in the payments overview and can
  # correct the bookkeeping.
  def sync_from_mollie!(mollie_payment)
    order.with_lock do
      reload
      self.status = mollie_payment.status unless paid?
      update_mollie_amount(:amount_refunded_cents, mollie_payment.try(:amount_refunded))
      update_mollie_amount(:amount_charged_back_cents, mollie_payment.try(:amount_charged_back))
      self.payment_method = mollie_reported_payment_method(mollie_payment) || payment_method
      self.processed_in_bookkeeping = false if will_save_change_to_amount_charged_back_cents? && charged_back?
      save!
    end
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
      amount: { value: format("%d.%02d", amount_cents / 100, amount_cents % 100), currency: "EUR" },
      description: description,
      redirect_url: redirect_url,
      webhook_url: webhook_url,
      metadata: mollie_metadata
    )

    raise Mollie::Exception, "No checkout URL was returned by Mollie." if mollie_payment.checkout_url.blank?

    update!(mollie_payment_id: mollie_payment.id)

    mollie_payment.checkout_url
  end

  # Records a simulated Mollie status, used by the development-only simulation
  # controls so a payment flow can be exercised without calling Mollie.
  def simulate_mollie_status!(status)
    order.with_lock { update!(status: status, mollie_payment_id: nil) }
  end

  private

  def paid_status_is_final
    errors.add(:status, "cannot change after payment is paid") if status_in_database == "paid" && !paid?
  end

  def prevent_creation_on_closed_order
    return unless order.closed?

    errors.add(:base, "A closed order cannot accept another payment")
    throw :abort
  end

  def prevent_reopening_paid_payment
    return if paid? || !self.class.where(id:, status: "paid").exists?

    errors.add(:status, "cannot change after payment is paid")
    throw :abort
  end

  def with_order_lock
    order.with_lock { yield }
  end

  def reprice_order_after_terminal_attempt
    return unless saved_change_to_status?
    return unless provider == "mollie" && status.in?(%w[canceled expired failed])

    OrderRepricingService.call(order: order, date: Date.current)
  end

  def update_mollie_amount(attribute, amount)
    value = mollie_amount_value(amount)
    self[attribute] = (value * 100).round if value
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

  def needs_mollie_payment_date?
    !manual? && payment_date.blank? && paid?
  end

  def mollie_metadata
    if hostel_booking
      { payment_id: id, order_id: order_id, hostel_booking_id: hostel_booking_id, user_id: hostel_booking.user_id }
    else
      { payment_id: id, order_id: order_id, participant_id: participant_id }
    end
  end

  def set_mollie_payment_date
    self.payment_date = (created_at || Time.current).to_date
  end

  def became_paid?
    saved_change_to_status? && paid?
  end

  def send_payment_confirmation
    recipient = order.user.email
    return if recipient.blank?

    # Atomic check-and-set prevents duplicate emails under concurrent webhook/redirect updates.
    return unless Payment.where(id: id, confirmation_sent: false).update_all(confirmation_sent: true) == 1

    if participants.exists?
      ParticipantMailer.payment_confirmation(self).deliver_now
    elsif hostel_booking
      HostelBookingMailer.payment_confirmation(self).deliver_now
    end
  rescue StandardError => e
    Rails.logger.error("Failed to deliver payment confirmation for Payment #{id}: #{e.class}: #{e.message}")
  end

  def covers_full_order_amount
    return if amount_cents == order&.total_cents

    errors.add(:amount_cents, "must equal the full order amount")
  end

  def order_is_submitted
    errors.add(:order, "must be submitted before payment") if order&.draft?
  end
end
