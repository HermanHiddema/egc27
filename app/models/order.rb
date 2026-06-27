class Order < ApplicationRecord
  # "cart" is the initial state for an item waiting in the user's shopping cart.
  # The remaining values mirror Mollie payment statuses so a checkout result can
  # be stored verbatim.
  STATUSES = %w[cart open pending authorized paid canceled expired failed].freeze

  # Order numbers shown to users are derived from the sequential id, offset so the
  # very first order starts at a friendlier-looking 10001.
  ORDER_NUMBER_OFFSET = 10_000

  belongs_to :user
  belongs_to :orderable, polymorphic: true, optional: true

  validates :description, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }

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

  def order_number
    return if id.nil?

    id + ORDER_NUMBER_OFFSET
  end
end
