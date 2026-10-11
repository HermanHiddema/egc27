require "test_helper"
require Rails.root.join("db/migrate/20261011220001_create_congress_pass_product").to_s

class ProductPricingTest < ActiveSupport::TestCase
  setup do
    @product = Product.create!(
      name: "T-shirt",
      category: "merchandise",
      vat_category: "standard",
      price_tiers: [
        PriceTier.new(name: "early", price_cents: 1_500, valid_until: Date.new(2027, 1, 31)),
        PriceTier.new(name: "regular", price_cents: 2_000)
      ]
    )
  end

  test "returns the price, tier name and valid until of the tier that applies on the date" do
    result = ProductPricing.call(product: @product, at: Date.new(2027, 1, 31))

    assert_equal 1_500, result.price_cents
    assert_equal "early", result.tier_name
    assert_equal Date.new(2027, 1, 31), result.tier_valid_until
  end

  test "returns the final tier after the last valid until date" do
    result = ProductPricing.call(product: @product, at: Date.new(2027, 2, 1))

    assert_equal 2_000, result.price_cents
    assert_equal "regular", result.tier_name
    assert_nil result.tier_valid_until
  end

  test "uses the date of the moment in the application time zone" do
    result = ProductPricing.call(product: @product, at: Time.zone.parse("2027-01-31 23:59:59"))

    assert_equal "early", result.tier_name
  end

  test "applies the participant discount for the age group of the participant" do
    @product.participant_discounts.create!(age_group: "12-17", discount_fraction: BigDecimal("0.25"))

    result = ProductPricing.call(product: @product, at: Date.new(2027, 2, 1), participant: Participant.new(age_group: "12-17"))

    assert_equal 1_500, result.price_cents
    assert_equal 2_000, result.base_price_cents
    assert_equal BigDecimal("0.25"), result.discount_fraction
  end

  test "does not apply a discount to participants of other age groups" do
    @product.participant_discounts.create!(age_group: "12-17", discount_fraction: BigDecimal("0.25"))

    result = ProductPricing.call(product: @product, at: Date.new(2027, 2, 1), participant: Participant.new(age_group: "18-49"))

    assert_equal 2_000, result.price_cents
  end

  test "rounds discounted prices to whole cents" do
    @product.participant_discounts.create!(age_group: "0-11", discount_fraction: BigDecimal("0.3333"))

    result = ProductPricing.call(product: @product, at: Date.new(2027, 1, 1), participant: Participant.new(age_group: "0-11"))

    assert_equal 1_000, result.price_cents
  end

  test "uses the price tiers of the variant" do
    variant = @product.variants.create!(
      name: "XL",
      price_tiers: [PriceTier.new(name: "regular", price_cents: 2_500)]
    )

    assert_equal 2_500, ProductPricing.call(product: @product, variant: variant, at: Date.new(2027, 1, 1)).price_cents
  end

  test "falls back to the price tiers of the product for a variant without tiers" do
    variant = @product.variants.create!(name: "M")

    assert_equal 1_500, ProductPricing.call(product: @product, variant: variant, at: Date.new(2027, 1, 1)).price_cents
  end

  test "rejects a variant of another product" do
    other = Product.create!(name: "Mug", category: "merchandise", vat_category: "standard")
    variant = other.variants.create!(name: "Blue")

    assert_raises(ArgumentError) { ProductPricing.new(product: @product, variant: variant) }
  end

  test "raises when the product has no price" do
    product = Product.create!(name: "Mug", category: "merchandise", vat_category: "standard")

    assert_raises(ProductPricing::NoPriceError) { ProductPricing.call(product: product) }
  end

  test "returns exactly the same congress pass prices as CongressPassPricing" do
    ActiveRecord::Migration.suppress_messages { CreateCongressPassProduct.new.migrate(:up) }
    congress_pass = Product.find_by!(code: "congress_pass")

    assert_equal "participation", congress_pass.category
    assert congress_pass.requires_participant
    assert_predicate congress_pass.vat_category, :present?
    assert_equal Participant::ATTENDANCE_OPTIONS.keys.sort, congress_pass.variants.map(&:code).sort

    tier_boundaries = CongressPassPricing::PRICE_TIERS.filter_map { |tier| tier[:until] }
    dates = tier_boundaries.flat_map { |date| [date - 1.day, date, date + 1.day] } + [Date.new(2025, 1, 1), Date.new(2030, 1, 1)]
    age_groups = Participant::AGE_GROUPS + [nil]

    congress_pass.variants.each do |variant|
      dates.each do |date|
        age_groups.each do |age_group|
          expected = CongressPassPricing.new(attendance_option: variant.code, payment_date: date, age_group: age_group)
          participant = age_group && Participant.new(age_group: age_group)
          result = ProductPricing.call(product: congress_pass, variant: variant, at: date, participant: participant)
          context = "#{variant.code} on #{date} for age group #{age_group.inspect}"

          assert_equal expected.price_cents, result.price_cents, context
          assert_equal expected.tier_name.to_s, result.tier_name, context
          if expected.current_tier_valid_until
            assert_equal expected.current_tier_valid_until, result.tier_valid_until, context
          else
            assert_nil result.tier_valid_until, context
          end
        end
      end
    end
  end
end
