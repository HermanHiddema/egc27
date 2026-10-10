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
# To avoid fetching the full settlement history, the first sync looks for the
# first settlement month by month (Mollie's year/month filter), starting at the
# month of the first payment. Later syncs use Mollie's `from` parameter to only
# fetch the settlements from the last known one onwards, starting at the oldest
# known settlement that is still open or pending so its status gets updated.
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

    from = resume_settlement_id(since) || first_settlement_id(since)
    return Result.new(settlements_count:, payments_count:) if from.nil?

    each_item(Mollie::Settlement.all(list_options(from:))) do |remote_settlement|
      next unless relevant?(remote_settlement, since)

      linked = sync_settlement(remote_settlement)
      next if linked.nil?

      settlements_count += 1
      payments_count += linked
    end

    Result.new(settlements_count:, payments_count:)
  end

  private

  # Settlements created before our first Mollie payment cannot contain any of
  # our payments. Returns nil when there are no Mollie payments yet.
  def first_payment_date
    Payment.where(provider: "mollie").minimum(:created_at)&.in_time_zone&.to_date
  end

  def list_options(**options)
    options[:balance_id] = @balance_id if @balance_id.present?
    options.merge(limit: PAGE_SIZE, api_key: @token)
  end

  def relevant?(remote_settlement, since)
    remote_settlement.id.present? && remote_settlement.created_at.present? &&
      remote_settlement.created_at.in_time_zone.to_date >= since
  end

  # The settlement to continue syncing from: the oldest known settlement that
  # can still change, or else the newest known settlement.
  def resume_settlement_id(since)
    known = Settlement.where(mollie_created_at: since.beginning_of_day..)
    known.where(status: %w[open pending]).order(:mollie_created_at, :id).pick(:mollie_settlement_id) ||
      known.order(mollie_created_at: :desc, id: :desc).pick(:mollie_settlement_id)
  end

  # Searches month by month, from the month of the first payment up to the
  # current month, for the first relevant settlement.
  def first_settlement_id(since)
    month = since.beginning_of_month
    while month <= Date.current
      first = nil
      list = Mollie::Settlement.all(list_options(year: month.year.to_s, month: month.month.to_s))
      each_item(list) do |remote_settlement|
        next unless relevant?(remote_settlement, since)

        first = remote_settlement if first.nil? || remote_settlement.created_at < first.created_at
      end
      return first.id if first

      month = month.next_month
    end
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
    # The payments of a settlement that was already paid out can no longer
    # change, so they do not need to be fetched again.
    return 0 if settlement.persisted? && settlement.status == "paidout" && status == "paidout" && settlement.payments_complete?

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

  # Iterates over all items of a paginated Mollie list.
  def each_item(list, &block)
    loop do
      list.each(&block)
      break if list.links.blank? || list.links["next"].blank?

      list = list.next(api_key: @token)
    end
  end

  def amount_cents(amount, settlement_id)
    if amount.nil? || amount.value.nil?
      raise Mollie::Exception, "Settlement #{settlement_id} is missing its payout amount."
    end

    (BigDecimal(amount.value.to_s) * 100).round
  end
end
