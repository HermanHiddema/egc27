class Order < ApplicationRecord
  # "cart" is the initial state for an item waiting in the user's shopping cart.
  # The remaining values mirror Mollie payment statuses so a checkout result can
  # be stored verbatim.
  STATUSES = %w[cart open pending authorized paid canceled expired failed].freeze

  # Human-readable, unique reference printed on confirmations and used in support.
  ORDER_NUMBER_PREFIX = "EGC".freeze

  belongs_to :user
  belongs_to :orderable, polymorphic: true, optional: true

  before_validation :assign_order_number, on: :create

  validates :description, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :order_number, presence: true, uniqueness: true

  scope :paid, -> { where(status: "paid") }
  scope :unpaid, -> { where.not(status: "paid") }
  scope :in_cart, -> { where(status: "cart") }
  scope :for_mollie_payment, ->(mollie_payment_id) { where(mollie_payment_id: mollie_payment_id) }
  scope :for_checkout_reference, ->(reference) { where(checkout_reference: reference) }

  def paid?
    status == "paid"
  end

  def amount_eur
    amount_cents / 100.0
  end

  def amount_formatted
    "€ #{format('%.2f', amount_eur)}"
  end

  private

  def assign_order_number
    return if order_number.present?

    loop do
      candidate = self.class.generate_order_number
      unless self.class.exists?(order_number: candidate)
        self.order_number = candidate
        break
      end
    end
  end

  def self.generate_order_number
    "#{ORDER_NUMBER_PREFIX}-#{Time.current.year}-#{SecureRandom.random_number(1_000_000).to_s.rjust(6, '0')}"
  end
end
