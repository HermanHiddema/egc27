class Payment < ApplicationRecord
  STATUSES = %w[open canceled pending authorized expired failed paid].freeze

  belongs_to :participant

  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :description, presence: true
  validates :mollie_payment_id, uniqueness: true, allow_nil: true

  scope :completed, -> { where(status: "paid") }
  scope :pending_or_open, -> { where(status: %w[open pending authorized]) }

  def paid?
    status == "paid"
  end

  def amount_eur
    amount_cents / 100.0
  end

  def amount_formatted
    "€ #{format('%.2f', amount_eur)}"
  end
end
