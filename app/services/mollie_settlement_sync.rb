# Fetches the settlements (payouts) from the Mollie Settlements API and links
# the payments that were paid out in each settlement, so admins can see which
# payments make up each payout. It also stores how the payout was calculated:
# the revenue and costs per period, the refunds and chargebacks deducted, and
# the details of payments from another webshop on the same Mollie account
# (which are not imported as payments).
#
# The Settlements API cannot be used with the regular Mollie API key; it needs
# an organization access token with the settlements.read, payments.read and
# refunds.read permissions, configured as `mollie_organization_token` in the
# credentials or as the MOLLIE_ORGANIZATION_TOKEN environment variable.
#
# Settlements are not limited to a single profile, so only the settlements
# created on or after the date of our first Mollie payment are synced. They can
# optionally be limited further to a single balance by setting the
# MOLLIE_SETTLEMENT_BALANCE_ID environment variable.
#
# Mollie lists settlements newest first, so the sync stops at the first
# settlement created before our first payment.
class MollieSettlementSync
  class NotConfigured < StandardError; end

  PAGE_SIZE = 250

  Result = Data.define(:settlements_count, :payments_count)

  def self.organization_token
    Rails.application.credentials.mollie_organization_token.presence ||
      ENV.fetch("MOLLIE_ORGANIZATION_TOKEN", nil).presence
  end

  def self.configured?
    organization_token.present?
  end

  def self.balance_id
    ENV.fetch("MOLLIE_SETTLEMENT_BALANCE_ID", nil).presence
  end

  def initialize(token: self.class.organization_token, balance_id: self.class.balance_id)
    @token = token
    @balance_id = balance_id
  end

  def call
    raise NotConfigured, "No Mollie organization access token is configured." if @token.blank?

    settlements_count = 0
    payments_count = 0

    since = first_payment_date
    return Result.new(settlements_count:, payments_count:) if since.nil?

    each_item(Mollie::Settlement.all(list_options)) do |remote_settlement|
      next if remote_settlement.id.blank? || remote_settlement.created_at.nil?
      throw :done if remote_settlement.created_at.in_time_zone.to_date < since

      linked = sync_settlement(remote_settlement)
      unless linked.nil?
        settlements_count += 1
        payments_count += linked
      end
    end

    Result.new(settlements_count:, payments_count:)
  end

  # Fetches a single settlement again. Returns the number of payments linked,
  # or nil when the settlement is skipped.
  def sync_one(mollie_settlement_id)
    raise NotConfigured, "No Mollie organization access token is configured." if @token.blank?

    sync_settlement(Mollie::Settlement.get(mollie_settlement_id, api_key: @token))
  end

  private

  # Settlements created before our first Mollie payment cannot contain any of
  # our payments. Returns nil when there are no Mollie payments yet.
  def first_payment_date
    Payment.where(provider: "mollie").minimum(:created_at)&.in_time_zone&.to_date
  end

  def list_options
    options = { limit: PAGE_SIZE, api_key: @token }
    options[:balance_id] = @balance_id if @balance_id.present?
    options
  end

  # Records the settlement and links its payments. Returns the number of
  # payments linked, or nil when the settlement is skipped.
  def sync_settlement(remote_settlement)
    status = remote_settlement.status.to_s
    unless Settlement::STATUSES.include?(status)
      Rails.logger.warn("[Mollie] Skipping settlement #{remote_settlement.id} with unknown status #{status.inspect}")
      return
    end

    payout_amount_cents = amount_cents(remote_settlement.amount, remote_settlement.id)
    settlement = Settlement.find_or_initialize_by(mollie_settlement_id: remote_settlement.id)
    remote_payments = settlement_payments(remote_settlement.id)
    mollie_payment_ids = remote_payments.pluck("id")
    remote_refunds = settlement_refunds(remote_settlement.id)
    remote_chargebacks = settlement_chargebacks(remote_settlement.id)
    periods = remote_settlement.attributes["periods"]

    other_payments = []

    Settlement.transaction do
      known_ids = Payment.where(mollie_payment_id: mollie_payment_ids).pluck(:mollie_payment_id)
      other_payments = remote_payments.reject { |payment| known_ids.include?(payment["id"]) }
      settlement.update!(
        reference: remote_settlement.reference,
        mollie_balance_id: remote_settlement.attributes["balance_id"].presence,
        status: status,
        amount_cents: payout_amount_cents,
        settled_at: remote_settlement.settled_at,
        mollie_created_at: remote_settlement.created_at,
        payments_complete: other_payments.all? { |payment| payment["amount_cents"] },
        periods: periods.is_a?(Hash) ? periods : {},
        other_payments: other_payments
      )

      linked_payments = Payment.where(settlement_id: settlement.id)
      if mollie_payment_ids.empty?
        linked_payments.update_all(settlement_id: nil, updated_at: Time.current)
      else
        linked_payments.where.not(mollie_payment_id: mollie_payment_ids)
          .update_all(settlement_id: nil, updated_at: Time.current)
      end

      Payment.where(mollie_payment_id: mollie_payment_ids)
        .update_all(settlement_id: settlement.id, updated_at: Time.current)

      sync_deductions(settlement, Refund, :mollie_refund_id, remote_refunds)
      sync_deductions(settlement, Chargeback, :mollie_chargeback_id, remote_chargebacks)
    end

    mollie_payment_ids.size - other_payments.size
  end

  # Records the refunds or chargebacks deducted from a settlement, linked to
  # our own payment when it is known here, and removes those that are no longer
  # part of it.
  def sync_deductions(settlement, model, id_column, remote_items)
    local_payments = Payment.where(mollie_payment_id: remote_items.filter_map { |item| item[:mollie_payment_id] })
      .index_by(&:mollie_payment_id)

    remote_items.each do |item|
      record = model.find_or_initialize_by(id_column => item[id_column])
      record.update!(item.merge(settlement: settlement, payment: local_payments[item[:mollie_payment_id]]))
    end

    model.where(settlement: settlement).where.not(id_column => remote_items.pluck(id_column)).destroy_all
  end

  # The payments paid out in a settlement, with the details needed to account
  # for the payout of payments that are not ours.
  def settlement_payments(mollie_settlement_id)
    payments = []
    list = Mollie::Settlement::Payment.all(settlement_id: mollie_settlement_id, limit: PAGE_SIZE, api_key: @token)
    each_item(list) do |remote_payment|
      next if remote_payment.id.blank?

      payments << {
        "id" => remote_payment.id,
        "description" => remote_payment.attributes["description"],
        "method" => remote_payment.attributes["method"],
        "status" => remote_payment.attributes["status"],
        "amount_cents" => Settlement.cents_from_amount(remote_payment.attributes["amount"]),
        "settlement_amount_cents" => Settlement.cents_from_amount(remote_payment.attributes["settlement_amount"]),
        "amount_refunded_cents" => Settlement.cents_from_amount(remote_payment.attributes["amount_refunded"]),
        "amount_charged_back_cents" => Settlement.cents_from_amount(remote_payment.attributes["amount_charged_back"]),
        "created_at" => remote_payment.attributes["created_at"]
      }
    end
    payments
  end

  def settlement_refunds(mollie_settlement_id)
    refunds = []
    list = Mollie::Settlement::Refund.all(settlement_id: mollie_settlement_id, limit: PAGE_SIZE, api_key: @token)
    each_item(list) do |refund|
      next if refund.id.blank?

      refunds << {
        mollie_refund_id: refund.id,
        mollie_payment_id: refund.payment_id.presence,
        description: refund.description,
        status: refund.status,
        amount_cents: Settlement.cents_from_amount(refund.attributes["amount"]),
        settlement_amount_cents: Settlement.cents_from_amount(refund.attributes["settlement_amount"]),
        mollie_created_at: Settlement.parse_time(refund.attributes["created_at"])
      }
    end
    refunds
  end

  def settlement_chargebacks(mollie_settlement_id)
    chargebacks = []
    list = Mollie::Settlement::Chargeback.all(settlement_id: mollie_settlement_id, limit: PAGE_SIZE, api_key: @token)
    each_item(list) do |chargeback|
      next if chargeback.id.blank?

      chargebacks << {
        mollie_chargeback_id: chargeback.id,
        mollie_payment_id: chargeback.payment_id.presence,
        amount_cents: Settlement.cents_from_amount(chargeback.attributes["amount"]),
        settlement_amount_cents: Settlement.cents_from_amount(chargeback.attributes["settlement_amount"]),
        mollie_created_at: Settlement.parse_time(chargeback.attributes["created_at"]),
        reversed_at: Settlement.parse_time(chargeback.attributes["reversed_at"])
      }
    end
    chargebacks
  end

  # Iterates over all items of a paginated Mollie list, until the block throws
  # :done.
  def each_item(list, &block)
    catch(:done) do
      loop do
        list.each(&block)
        break if list.links.blank? || list.links["next"].blank?

        list = list.next(api_key: @token)
      end
    end
  end

  def amount_cents(amount, settlement_id)
    if amount.nil? || amount.value.nil?
      raise Mollie::Exception, "Settlement #{settlement_id} is missing its payout amount."
    end

    (BigDecimal(amount.value.to_s) * 100).round
  end
end
