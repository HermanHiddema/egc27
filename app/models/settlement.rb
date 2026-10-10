# == Schema Information
#
# Table name: settlements
#
#  id                   :bigint           not null, primary key
#  amount_cents         :integer          default(0), not null
#  mollie_created_at    :datetime
#  payments_complete    :boolean          default(FALSE), not null
#  reference            :string
#  settled_at           :datetime
#  status               :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  mollie_settlement_id :string           not null
#
# Indexes
#
#  index_settlements_on_mollie_settlement_id  (mollie_settlement_id) UNIQUE
#
# A payout by Mollie of the payments received in a period, minus the fees
# Mollie charged (and any refunds or chargebacks). Settlements are synced from
# the Mollie Settlements API by MollieSettlementSync, which also links the
# payments that were paid out in each settlement.
class Settlement < ApplicationRecord
  STATUSES = %w[open pending paidout failed].freeze
  STATUS_LABELS = { "paidout" => "Paid out" }.freeze

  has_many :payments, dependent: :nullify

  validates :mollie_settlement_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true }

  scope :newest_first, -> { order(Arel.sql("COALESCE(settled_at, mollie_created_at, created_at) DESC"), id: :desc) }

  def self.format_cents(cents)
    sign = cents.negative? ? "-" : ""
    "#{sign}€ #{format('%.2f', cents.abs / 100.0)}"
  end

  def status_label
    STATUS_LABELS.fetch(status) { status.humanize }
  end

  def amount_formatted
    self.class.format_cents(amount_cents)
  end

  # The gross amount of the payments known here that were paid out in this
  # settlement.
  def payments_total_cents
    payments.loaded? ? payments.sum(&:amount_cents) : payments.sum(:amount_cents)
  end

  # What Mollie kept from the payments in this settlement, when all its
  # payments are known locally.
  def deductions_cents
    return unless payments_complete?

    payments_total_cents - amount_cents
  end
end
