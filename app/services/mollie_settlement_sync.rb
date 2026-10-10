# Fetches the settlements (payouts) from the Mollie Settlements API and links
# the payments that were paid out in each settlement, so admins can see which
# payments make up each payout.
#
# The Settlements API cannot be used with the regular Mollie API key; it needs
# an organization access token with the settlements.read and payments.read
# permissions, configured as `mollie_organization_token` in the credentials or
# as the MOLLIE_ORGANIZATION_TOKEN environment variable.
#
# Settlements are not limited to a single profile, so only the settlements
# created on or after the date of our first Mollie payment are synced. They can
# optionally be limited further to a single balance by setting the
# MOLLIE_SETTLEMENT_BALANCE_ID environment variable.
#
# Mollie lists settlements newest first, so to avoid fetching the full
# settlement history the sync stops at the first settlement created before our
# first payment, or once it reaches a settlement that was already synced and can
# no longer change (paid out or failed), as long as no older synced settlement
# is still open or pending.
class MollieSettlementSync
  class NotConfigured < StandardError; end

  PAGE_SIZE = 250
  FINAL_STATUSES = %w[paidout failed].freeze

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

    final_ids = Settlement.where(status: FINAL_STATUSES).pluck(:mollie_settlement_id).to_set
    oldest_unfinished_at = Settlement.where.not(status: FINAL_STATUSES).minimum(:mollie_created_at)

    each_item(Mollie::Settlement.all(list_options)) do |remote_settlement|
      next if remote_settlement.id.blank? || remote_settlement.created_at.nil?
      throw :done if remote_settlement.created_at.in_time_zone.to_date < since

      linked = sync_settlement(remote_settlement)
      unless linked.nil?
        settlements_count += 1
        payments_count += linked
      end

      if final_ids.include?(remote_settlement.id) &&
          (oldest_unfinished_at.nil? || remote_settlement.created_at < oldest_unfinished_at)
        throw :done
      end
    end

    Result.new(settlements_count:, payments_count:)
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
    mollie_payment_ids = settlement_payment_ids(remote_settlement.id)

    Settlement.transaction do
      payments_complete = Payment.where(mollie_payment_id: mollie_payment_ids).count == mollie_payment_ids.size
      settlement.update!(
        reference: remote_settlement.reference,
        status: status,
        amount_cents: payout_amount_cents,
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
