# Fetches the settlements (payouts) from the Mollie Settlements API and links
# the payments that were paid out in each settlement, so admins can see which
# payments make up each payout.
#
# The Settlements API cannot be used with the regular Mollie API key; it needs
# an organization access token with the settlements.read and payments.read
# permissions, configured as `mollie_organization_token` in the credentials or
# as the MOLLIE_ORGANIZATION_TOKEN environment variable.
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

  def initialize(token: self.class.organization_token)
    @token = token
  end

  def call
    raise NotConfigured, "No Mollie organization access token is configured." if @token.blank?

    settlements_count = 0
    payments_count = 0

    each_item(Mollie::Settlement.all(limit: PAGE_SIZE, api_key: @token)) do |remote_settlement|
      next if remote_settlement.id.blank?

      linked = sync_settlement(remote_settlement)
      next if linked.nil?

      settlements_count += 1
      payments_count += linked
    end

    Result.new(settlements_count:, payments_count:)
  end

  private

  # Records the settlement and links its payments. Returns the number of
  # payments linked, or nil when the settlement is skipped.
  def sync_settlement(remote_settlement)
    status = remote_settlement.status.to_s
    unless Settlement::STATUSES.include?(status)
      Rails.logger.warn("[Mollie] Skipping settlement #{remote_settlement.id} with unknown status #{status.inspect}")
      return
    end

    settlement = Settlement.find_or_initialize_by(mollie_settlement_id: remote_settlement.id)
    # The payments of a settlement that was already paid out can no longer
    # change, so they do not need to be fetched again.
    return 0 if settlement.persisted? && settlement.status == "paidout" && status == "paidout" && settlement.payments_complete?

    mollie_payment_ids = settlement_payment_ids(remote_settlement.id)

    Settlement.transaction do
      payments_complete = Payment.where(mollie_payment_id: mollie_payment_ids).count == mollie_payment_ids.size
      settlement.update!(
        reference: remote_settlement.reference,
        status: status,
        amount_cents: amount_cents(remote_settlement.amount),
        settled_at: remote_settlement.settled_at,
        mollie_created_at: remote_settlement.created_at,
        payments_complete: payments_complete
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
    end
  end

  def settlement_payment_ids(mollie_settlement_id)
    ids = []
    list = Mollie::Settlement::Payment.all(settlement_id: mollie_settlement_id, limit: PAGE_SIZE, api_key: @token)
    each_item(list) { |remote_payment| ids << remote_payment.id if remote_payment.id.present? }
    ids
  end

  # Iterates over all items of a paginated Mollie list.
  def each_item(list, &block)
    loop do
      list.each(&block)
      break if list.links.blank? || list.links["next"].blank?

      list = list.next(api_key: @token)
    end
  end

  def amount_cents(amount)
    return 0 if amount.nil? || amount.value.nil?

    (amount.value * 100).round
  end
end
