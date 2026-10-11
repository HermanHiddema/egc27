# Shared behaviour for records that carry their own price tiers (products and
# product variants). The tiers of a single owner form a schedule: each tier is
# valid until (and including) its valid_until date, and exactly one final tier
# (without valid_until) applies after the last date.
module PriceTierOwner
  extend ActiveSupport::Concern

  included do
    validate :price_tiers_form_a_schedule
  end

  # The tiers that will be persisted, ordered by valid_until with the final
  # tier last.
  def price_tier_schedule
    price_tiers.reject(&:marked_for_destruction?).sort_by { |tier| [tier.valid_until ? 0 : 1, tier.valid_until || Date.new] }
  end

  # The tier that applies on the given date, or nil when there are no tiers.
  def price_tier_on(date)
    price_tier_schedule.find { |tier| tier.valid_until.nil? || date <= tier.valid_until }
  end

  private

  def price_tiers_form_a_schedule
    tiers = price_tier_schedule
    return if tiers.empty?

    final_tiers = tiers.count { |tier| tier.valid_until.nil? }
    errors.add(:price_tiers, "must include exactly one final tier without a valid until date") unless final_tiers == 1

    dates = tiers.filter_map(&:valid_until)
    errors.add(:price_tiers, "must have unique valid until dates") unless dates.uniq.size == dates.size

    names = tiers.map(&:name)
    errors.add(:price_tiers, "must have unique names") unless names.uniq.size == names.size
  end
end
