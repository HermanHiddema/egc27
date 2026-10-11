# == Schema Information
#
# Table name: settlements
#
#  id                   :bigint           not null, primary key
#  amount_cents         :integer          default(0), not null
#  chargebacks          :jsonb            not null
#  mollie_created_at    :datetime
#  payments_complete    :boolean          default(FALSE), not null
#  periods              :jsonb            not null
#  reference            :string
#  refunds              :jsonb            not null
#  settled_at           :datetime
#  status               :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  mollie_balance_id    :string
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

  # A revenue or cost line of a period in the Mollie breakdown of a settlement.
  BreakdownLine = Data.define(:description, :payment_method, :count, :net_cents, :vat_cents, :gross_cents)
  # The revenue and costs of a month in the Mollie breakdown of a settlement.
  Period = Data.define(:year, :month, :revenue, :costs, :invoice_id) do
    def label
      Date.new(year, month).strftime("%B %Y")
    end

    def revenue_cents
      revenue.sum { |line| line.gross_cents.to_i }
    end

    def costs_cents
      costs.sum { |line| line.gross_cents.to_i }
    end
  end

  has_many :payments, dependent: :nullify

  validates :mollie_settlement_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true }

  scope :newest_first, -> { order(Arel.sql("COALESCE(settled_at, mollie_created_at, created_at) DESC"), id: :desc) }

  # Converts a Mollie amount ({ "value" => "1.23", "currency" => "EUR" }) to
  # cents. Returns nil when there is no amount.
  def self.cents_from_amount(amount)
    value = amount.is_a?(Hash) ? amount["value"] : nil
    return if value.blank?

    (BigDecimal(value.to_s) * 100).round
  rescue ArgumentError
    nil
  end

  def self.parse_time(value)
    Time.zone.parse(value.to_s) if value.present?
  rescue ArgumentError
    nil
  end

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

  # The revenue and costs per month that make up the payout, as reported by
  # Mollie, oldest first.
  def breakdown_periods
    (periods || {}).flat_map do |year, months|
      next [] unless months.is_a?(Hash) && year.to_s.match?(/\A\d{4}\z/)

      months.filter_map do |month, period|
        next unless period.is_a?(Hash) && month.to_s.match?(/\A\d{1,2}\z/) && month.to_i.between?(1, 12)

        Period.new(
          year: year.to_i,
          month: month.to_i,
          revenue: breakdown_lines(period["revenue"]),
          costs: breakdown_lines(period["costs"]),
          invoice_id: period["invoice_id"].presence
        )
      end
    end.sort_by { |period| [period.year, period.month] }
  end

  def refunds_total_cents
    Array(refunds).sum { |refund| refund["settlement_amount_cents"].to_i }
  end

  def chargebacks_total_cents
    Array(chargebacks).sum { |chargeback| chargeback["settlement_amount_cents"].to_i }
  end

  private

  def breakdown_lines(lines)
    Array(lines).filter_map do |line|
      next unless line.is_a?(Hash)

      BreakdownLine.new(
        description: line["description"].presence || line["method"].to_s.humanize,
        payment_method: line["method"],
        count: line["count"],
        net_cents: self.class.cents_from_amount(line["amount_net"]),
        vat_cents: self.class.cents_from_amount(line["amount_vat"]),
        gross_cents: self.class.cents_from_amount(line["amount_gross"])
      )
    end
  end
end
