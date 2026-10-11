# Shows the payouts made by Mollie and the payments paid out in each of them.
class Admin::SettlementsController < ApplicationController
  before_action :require_admin!

  def index
    @settlements = Settlement.newest_first.includes(:payments)
    @configured = MollieSettlementSync.configured?
  end

  def show
    @settlement = Settlement.find(params[:id])
    @payments = @settlement.payments.includes(:participant).order(created_at: :desc, id: :desc)
    @configured = MollieSettlementSync.configured?
    deducted_payment_ids = (@settlement.refunds + @settlement.chargebacks).filter_map { |item| item["payment_id"] }
    @deducted_payments = Payment.where(mollie_payment_id: deducted_payment_ids).includes(:participant).index_by(&:mollie_payment_id)
  end

  def sync
    result = MollieSettlementSync.new.call
    redirect_to admin_settlements_path,
      notice: "Synced #{helpers.pluralize(result.settlements_count, "settlement")} with Mollie; " \
              "#{helpers.pluralize(result.payments_count, "payment")} linked."
  rescue MollieSettlementSync::NotConfigured => e
    redirect_to admin_settlements_path, alert: e.message
  rescue Mollie::Exception => e
    Rails.logger.error("[Mollie] Error syncing settlements: #{e.message}")
    redirect_to admin_settlements_path, alert: "Settlements could not be synced with Mollie: #{e.message}"
  end

  def resync
    settlement = Settlement.find(params[:id])
    linked = MollieSettlementSync.new.sync_one(settlement.mollie_settlement_id)
    if linked.nil?
      redirect_to admin_settlement_path(settlement), alert: "Settlement could not be synced: Mollie reported an unknown status."
    else
      redirect_to admin_settlement_path(settlement),
        notice: "Synced settlement with Mollie; #{helpers.pluralize(linked, "payment")} linked."
    end
  rescue MollieSettlementSync::NotConfigured => e
    redirect_to admin_settlement_path(settlement), alert: e.message
  rescue Mollie::Exception => e
    Rails.logger.error("[Mollie] Error syncing settlement #{settlement.mollie_settlement_id}: #{e.message}")
    redirect_to admin_settlement_path(settlement), alert: "Settlement could not be synced with Mollie: #{e.message}"
  end
end
