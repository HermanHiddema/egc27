# == Schema Information
#
# Table name: hostel_bookings
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer          not null
#  arrival_date      :date             not null
#  breakfasts        :integer          default(0), not null
#  confirmation_sent :boolean          default(FALSE), not null
#  departure_date    :date             not null
#  double_rooms      :integer          default(0), not null
#  female_dorm_beds  :integer          default(0), not null
#  mixed_dorm_beds   :integer          default(0), not null
#  payment_method    :string
#  priced_on         :date             not null
#  single_rooms      :integer          default(0), not null
#  six_person_rooms  :integer          default(0), not null
#  status            :string           default("open"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  mollie_payment_id :string
#  user_id           :bigint           not null
#
# Indexes
#
#  index_hostel_bookings_on_mollie_payment_id  (mollie_payment_id) UNIQUE
#  index_hostel_bookings_on_status             (status)
#  index_hostel_bookings_on_user_id            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class HostelBooking < ApplicationRecord
  ROOM_TYPES = HostelPricing::ROOM_TYPES.keys.freeze
  # "refunded" and "charged_back" are recorded by us for payments that Mollie
  # keeps as "paid" but reports a refunded or charged-back amount for.
  STATUSES = Payment::STATUSES
  # Mollie statuses from which a checkout can still be completed, so its
  # checkout URL can be reused instead of starting a new payment attempt.
  RETRYABLE_MOLLIE_STATUSES = Payment::RETRYABLE_MOLLIE_STATUSES

  has_paper_trail

  belongs_to :user

  validates :arrival_date, :departure_date, presence: true
  validates :arrival_date, comparison: { greater_than_or_equal_to: HostelPricing::FIRST_ARRIVAL_DATE,
                                         message: "can not be before 24 July 2027" }, allow_nil: true
  validates :departure_date, comparison: { less_than_or_equal_to: HostelPricing::LAST_DEPARTURE_DATE,
                                           message: "can not be after 7 August 2027" }, allow_nil: true
  validates :departure_date, comparison: { greater_than: :arrival_date, message: "must be after the arrival date" },
            if: -> { arrival_date.present? && departure_date.present? }
  validates(*ROOM_TYPES, :breakfasts, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 99 })
  validate :at_least_one_room_or_bed
  validate :breakfasts_not_more_than_guests
  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :mollie_payment_id, uniqueness: true, allow_nil: true

  # The price follows the pricing period in which the booking is paid, so it is
  # calculated when the booking is made and again for every new checkout.
  before_validation :calculate_amount, on: :create

  after_commit :send_payment_confirmation, on: [:create, :update], if: :became_paid?

  scope :paid, -> { where(status: "paid") }

  # Records the state of a Mollie payment reported through the webhook. Returns
  # the updated booking, or nil when the payment is not for a hostel booking.
  def self.sync_from_mollie_webhook(mollie_id)
    mollie_payment = Mollie::Payment.get(mollie_id)
    booking = find_by(mollie_payment_id: mollie_payment.id)
    booking&.sync_from_mollie!(mollie_payment)
    booking
  end

  def nights
    return 0 if arrival_date.blank? || departure_date.blank?

    [(departure_date - arrival_date).to_i, 0].max
  end

  def guests
    ROOM_TYPES.sum { |room_type| self[room_type].to_i * HostelPricing::ROOM_TYPES.dig(room_type, :guests) }
  end

  # The price calculation of this booking, one line per booked item, at the
  # prices of the pricing period it was priced in.
  def price_lines
    HostelPricing.new(payment_date: priced_on || Date.current).line_items(
      nights: nights,
      rooms: ROOM_TYPES.index_with { |room_type| self[room_type] },
      breakfasts: breakfasts
    )
  end

  def description
    "EGC 2027 Hostel booking #{id} (#{arrival_date.strftime('%-d %b')} – #{departure_date.strftime('%-d %b %Y')})"
  end

  def paid?
    status == "paid"
  end

  # Refunded and charged-back bookings were cancelled, so they can not be paid
  # again; a new booking has to be made instead.
  def payable?
    !paid? && !Payment::REVERSED_STATUSES.include?(status)
  end

  def amount_eur
    amount_cents.to_i / 100.0
  end

  def amount_formatted
    "€ #{format('%.2f', amount_eur)}"
  end

  # Fetches the payment at Mollie, or nil when it was never started there.
  def mollie_payment
    return if mollie_payment_id.blank?

    Mollie::Payment.get(mollie_payment_id)
  end

  def sync_from_mollie!(mollie_payment)
    self.status = mollie_status(mollie_payment)
    attributes = mollie_payment.try(:attributes)
    reported_method = (attributes["method"] || attributes[:method]).presence if attributes.respond_to?(:[])
    self.payment_method = reported_method || payment_method
    save!
  end

  # Records the current state of the payment at Mollie. Returns the Mollie
  # payment, or nil when there is nothing to refresh.
  def refresh_from_mollie!
    mollie_payment.tap do |remote|
      sync_from_mollie!(remote) if remote&.status.present?
    end
  end

  # Like #refresh_from_mollie!, but logs errors instead of raising.
  def refresh_from_mollie
    refresh_from_mollie!
  rescue Mollie::Exception => e
    Rails.logger.error "[Mollie] Error fetching hostel booking payment #{mollie_payment_id}: #{e.message}"
    nil
  end

  # Refreshes the booking from Mollie and returns the checkout URL when the
  # checkout that was already started can still be completed.
  def resume_mollie_checkout!
    remote_payment = refresh_from_mollie!

    return if remote_payment.blank? || remote_payment.checkout_url.blank?
    return unless RETRYABLE_MOLLIE_STATUSES.include?(remote_payment.status)

    remote_payment.checkout_url
  end

  # Starts a new checkout at Mollie for the current price of this booking and
  # returns its checkout URL.
  def start_mollie_checkout!(redirect_url:, webhook_url:)
    calculate_amount
    self.status = "open"
    save!

    mollie_payment = Mollie::Payment.create(
      amount: { value: format("%.2f", amount_eur), currency: "EUR" },
      description: description,
      redirect_url: redirect_url,
      webhook_url: webhook_url,
      metadata: { hostel_booking_id: id, user_id: user_id }
    )

    raise Mollie::Exception, "No checkout URL was returned by Mollie." if mollie_payment.checkout_url.blank?

    update!(mollie_payment_id: mollie_payment.id)

    mollie_payment.checkout_url
  end

  # Records a simulated Mollie status, used by the development-only simulation
  # controls so the booking flow can be exercised without calling Mollie.
  def simulate_mollie_status!(status)
    update!(status: status, mollie_payment_id: nil)
  end

  private

  def calculate_amount
    self.priced_on = Date.current
    self.amount_cents = price_lines.sum(&:subtotal_cents)
  end

  def at_least_one_room_or_bed
    errors.add(:base, "Please book at least one room or bed") if guests.zero?
  end

  def breakfasts_not_more_than_guests
    return if breakfasts.to_i <= guests

    errors.add(:breakfasts, "can not be more than the number of guests (#{guests})")
  end

  def mollie_status(mollie_payment)
    return "charged_back" if mollie_amount_positive?(mollie_payment.try(:amount_charged_back))
    return "refunded" if mollie_amount_positive?(mollie_payment.try(:amount_refunded))

    mollie_payment.status
  end

  def mollie_amount_positive?(amount)
    return false if amount.blank?

    value = amount.respond_to?(:value) ? amount.value : (amount["value"] || amount[:value])
    value.present? && BigDecimal(value.to_s).positive?
  end

  def became_paid?
    saved_change_to_status? && paid?
  end

  def send_payment_confirmation
    return unless HostelBooking.where(id: id, confirmation_sent: false).update_all(confirmation_sent: true) == 1

    HostelBookingMailer.payment_confirmation(self).deliver_now
  rescue StandardError => e
    Rails.logger.error("Failed to deliver payment confirmation for HostelBooking #{id}: #{e.class}: #{e.message}")
  end
end
