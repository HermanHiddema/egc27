# Determines the VAT inclusive price of a product (or one of its variants) at
# a moment in time, for an optional participant. The price tier is taken from
# the variant, falling back to the product's own tiers, and the product's
# participant discount for the participant's age group is applied.
class ProductPricing
  Result = Data.define(:price_cents, :base_price_cents, :discount_fraction, :tier_name, :tier_valid_until)

  class NoPriceError < StandardError; end

  attr_reader :product, :variant, :at, :participant

  def self.call(...)
    new(...).call
  end

  def initialize(product:, variant: nil, at: Time.current, participant: nil)
    raise ArgumentError, "variant does not belong to product" if variant && variant.product_id != product.id

    @product = product
    @variant = variant
    @at = at
    @participant = participant
  end

  def call
    tier = price_tier
    raise NoPriceError, "#{[product.name, variant&.name].compact.join(' ')} has no price on #{date}" unless tier

    discount_fraction = product.discount_fraction_for(participant)
    price_cents = (tier.price_cents * (1 - discount_fraction)).round

    Result.new(
      price_cents: price_cents,
      base_price_cents: tier.price_cents,
      discount_fraction: discount_fraction,
      tier_name: tier.name,
      tier_valid_until: tier.valid_until
    )
  end

  private

  def date
    at.instance_of?(Date) ? at : at.in_time_zone.to_date
  end

  def price_tier
    variant&.price_tier_on(date) || product.price_tier_on(date)
  end
end
