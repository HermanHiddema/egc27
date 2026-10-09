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
end
