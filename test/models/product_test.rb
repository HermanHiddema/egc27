require "test_helper"

class ProductTest < ActiveSupport::TestCase
  def build_product(**attributes)
    Product.new({ name: "Dinner", category: "meal_voucher", vat_category: "reduced" }.merge(attributes))
  end

  test "is valid with a name, category and VAT category" do
    product = build_product

    assert product.valid?
    assert product.available
    assert_not product.requires_participant
  end

  test "requires a known category" do
    product = build_product(category: "tickets")

    assert_not product.valid?
    assert_includes product.errors[:category], "must be selected"
  end

  test "requires a VAT category" do
    product = build_product(vat_category: nil)

    assert_not product.valid?
    assert_includes product.errors[:vat_category], "must be selected"
  end

  test "exposes the VAT rate of its VAT category" do
    assert_equal BigDecimal("0.21"), build_product(vat_category: "standard").vat_rate
    assert_equal BigDecimal("0.09"), build_product(vat_category: "reduced").vat_rate
  end

  test "requires exactly one final price tier" do
    product = build_product(price_tiers: [PriceTier.new(name: "early", price_cents: 1_000, valid_until: Date.new(2027, 1, 31))])

    assert_not product.valid?
    assert_includes product.errors[:price_tiers], "must include exactly one final tier without a valid until date"

    product.price_tiers.build(name: "regular", price_cents: 1_200)
    assert product.valid?

    product.price_tiers.build(name: "late", price_cents: 1_400)
    assert_not product.valid?
  end

  test "requires unique valid until dates for its price tiers" do
    product = build_product(price_tiers: [
      PriceTier.new(name: "special", price_cents: 800, valid_until: Date.new(2027, 1, 31)),
      PriceTier.new(name: "early", price_cents: 1_000, valid_until: Date.new(2027, 1, 31)),
      PriceTier.new(name: "regular", price_cents: 1_200)
    ])

    assert_not product.valid?
    assert_includes product.errors[:price_tiers], "must have unique valid until dates"
  end

  test "orders its price tiers by valid until with the final tier last" do
    product = build_product(price_tiers: [
      PriceTier.new(name: "regular", price_cents: 1_200),
      PriceTier.new(name: "early", price_cents: 1_000, valid_until: Date.new(2027, 1, 31)),
      PriceTier.new(name: "special", price_cents: 800, valid_until: Date.new(2026, 8, 31))
    ])
    product.save!

    assert_equal %w[special early regular], product.reload.price_tiers.map(&:name)
    assert_equal %w[special early regular], product.price_tier_schedule.map(&:name)
  end

  test "requires positive prices" do
    tier = PriceTier.new(product: build_product, name: "regular", price_cents: 0)

    assert_not tier.valid?
    assert_includes tier.errors[:price_cents], "must be greater than 0"
  end

  test "price tier belongs to exactly one of a product or a variant" do
    product = build_product
    variant = product.variants.build(name: "Vegetarian")

    assert_not PriceTier.new(name: "regular", price_cents: 100).valid?
    assert_not PriceTier.new(product: product, product_variant: variant, name: "regular", price_cents: 100).valid?
    assert PriceTier.new(product_variant: variant, name: "regular", price_cents: 100).valid?
  end

  test "variant requires exactly one final price tier" do
    product = build_product
    variant = product.variants.build(name: "Vegetarian", price_tiers: [
      PriceTier.new(name: "early", price_cents: 1_000, valid_until: Date.new(2027, 1, 31))
    ])

    assert_not variant.valid?
    assert_includes variant.errors[:price_tiers], "must include exactly one final tier without a valid until date"
  end

  test "participant discount requires a known age group and a fraction between 0 and 1" do
    product = build_product

    assert product.participant_discounts.build(age_group: "0-11", discount_fraction: BigDecimal("0.8")).valid?
    assert_not product.participant_discounts.build(age_group: "kids", discount_fraction: BigDecimal("0.8")).valid?
    assert_not product.participant_discounts.build(age_group: "0-11", discount_fraction: BigDecimal("1.5")).valid?
    assert_not product.participant_discounts.build(age_group: "0-11", discount_fraction: 0).valid?
  end
end
