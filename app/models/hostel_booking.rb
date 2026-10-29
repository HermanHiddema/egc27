# == Schema Information
#
# Table name: hostel_bookings
#
#  id                          :bigint           not null, primary key
#  amount_cents                :integer          not null
#  arrival_date                :date             not null
#  breakfast_price_cents       :integer          not null
#  breakfasts                  :integer          default(0), not null
#  departure_date              :date             not null
#  double_room_price_cents     :integer          not null
#  double_rooms                :integer          default(0), not null
#  female_dorm_bed_price_cents :integer          not null
#  female_dorm_beds            :integer          default(0), not null
#  mixed_dorm_bed_price_cents  :integer          not null
#  mixed_dorm_beds             :integer          default(0), not null
#  priced_on                   :date             not null
#  single_room_price_cents     :integer          not null
#  single_rooms                :integer          default(0), not null
#  six_person_room_price_cents :integer          not null
#  six_person_rooms            :integer          default(0), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  user_id                     :bigint           not null
#
# Indexes
#
#  index_hostel_bookings_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class HostelBooking < ApplicationRecord
  ROOM_TYPES = HostelPricing::ROOM_TYPES.keys.freeze
  ROOM_PRICE_COLUMNS = {
    "single_rooms" => :single_room_price_cents,
    "double_rooms" => :double_room_price_cents,
    "six_person_rooms" => :six_person_room_price_cents,
    "mixed_dorm_beds" => :mixed_dorm_bed_price_cents,
    "female_dorm_beds" => :female_dorm_bed_price_cents
  }.freeze
  has_paper_trail

  attr_readonly :priced_on, *ROOM_PRICE_COLUMNS.values, :breakfast_price_cents, :amount_cents

  belongs_to :user
  has_many :payments, -> { order(created_at: :desc, id: :desc) }, dependent: :restrict_with_error

  before_create :lock_price
  before_destroy :prevent_destruction_with_financial_history

  validates :arrival_date, :departure_date, presence: true
  validates :arrival_date, comparison: { greater_than_or_equal_to: HostelPricing::FIRST_ARRIVAL_DATE,
                                         message: "can not be before 24 July 2027" }, allow_nil: true
  validates :departure_date, comparison: { less_than_or_equal_to: HostelPricing::LAST_DEPARTURE_DATE,
                                           message: "can not be after 7 August 2027" }, allow_nil: true
  validates :departure_date, comparison: { greater_than: :arrival_date, message: "must be after the arrival date" },
            if: -> { arrival_date.present? && departure_date.present? }
  validates(*ROOM_TYPES, :breakfasts, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 99 })
  validate :at_least_one_room_or_bed
  validate :breakfasts_not_more_than_beds

  def nights
    return 0 if arrival_date.blank? || departure_date.blank?

    [(departure_date - arrival_date).to_i, 0].max
  end

  def beds
    ROOM_TYPES.sum { |room_type| self[room_type].to_i * HostelPricing::ROOM_TYPES.dig(room_type, :beds) }
  end

  # The price calculation for this booking at the pricing period when it was made.
  def price_lines
    pricing = HostelPricing.new(payment_date: priced_on || Date.current)
    pricing.line_items(
      nights: nights,
      rooms: ROOM_TYPES.index_with { |room_type| self[room_type] },
      breakfasts: breakfasts,
      room_prices_cents: ROOM_PRICE_COLUMNS.to_h do |room_type, price_column|
        [room_type, self[price_column] || pricing.room_price_cents(room_type)]
      end,
      breakfast_price_cents: breakfast_price_cents || HostelPricing::BREAKFAST_CENTS
    )
  end

  def description
    "EGC 2027 Hostel booking #{id} (#{arrival_date.strftime('%-d %b')} – #{departure_date.strftime('%-d %b %Y')})"
  end

  def current_payment
    payments.first
  end

  def paid?
    current_payment&.paid? || false
  end

  def payable?
    payment = current_payment
    payment.nil? || payment.payable?
  end

  def financial_history_or_active_checkout?
    payments.exists?
  end

  def payment_status
    current_payment&.status || "unpaid"
  end

  def status
    payment_status
  end

  def amount_formatted
    "€ #{format('%.2f', amount_cents / 100.0)}"
  end

  private

  def lock_price
    self.priced_on = Date.current
    pricing = HostelPricing.new(payment_date: priced_on)
    ROOM_PRICE_COLUMNS.each do |room_type, price_column|
      self[price_column] = pricing.room_price_cents(room_type)
    end
    self.breakfast_price_cents = HostelPricing::BREAKFAST_CENTS
    self.amount_cents = price_lines.sum(&:subtotal_cents)
  end

  def prevent_destruction_with_financial_history
    return unless financial_history_or_active_checkout?

    errors.add(:base, "Cannot delete a hostel booking with financial history or an active checkout")
    throw(:abort)
  end

  def at_least_one_room_or_bed
    errors.add(:base, "Please book at least one room or bed") if beds.zero?
  end

  def breakfasts_not_more_than_beds
    return if breakfasts.to_i <= beds

    errors.add(:breakfasts, "can not be more than the number of beds (#{beds})")
  end
end
