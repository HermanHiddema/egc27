class CreateCongressPassProduct < ActiveRecord::Migration[8.1]
  CODE = "congress_pass".freeze

  VARIANTS = [
    { code: "all_events", name: "All events",
      prices: { special: 19_000, early: 22_000, regular: 26_000, late: 30_000 } },
    { code: "first_week_plus_weekend", name: "Week 1 + Weekend",
      prices: { special: 13_000, early: 16_000, regular: 19_000, late: 23_000 } },
    { code: "weekend_plus_second_week", name: "Weekend + Week 2",
      prices: { special: 13_000, early: 16_000, regular: 19_000, late: 23_000 } },
    { code: "weekend_only", name: "Weekend Only",
      prices: { special: 5_000, early: 6_000, regular: 7_000, late: 8_000 } }
  ].freeze

  TIER_VALID_UNTIL = {
    special: Date.new(2026, 8, 31),
    early: Date.new(2027, 1, 31),
    regular: Date.new(2027, 5, 31),
    late: nil
  }.freeze

  YOUTH_DISCOUNTS = {
    "0-11" => BigDecimal("0.80"),
    "12-17" => BigDecimal("0.50")
  }.freeze

  class MigrationProduct < ActiveRecord::Base
    self.table_name = "products"
  end

  class MigrationProductVariant < ActiveRecord::Base
    self.table_name = "product_variants"
  end

  class MigrationPriceTier < ActiveRecord::Base
    self.table_name = "price_tiers"
  end

  class MigrationParticipantDiscount < ActiveRecord::Base
    self.table_name = "participant_discounts"
  end

  def up
    return if MigrationProduct.exists?(code: CODE)

    product = MigrationProduct.create!(
      code: CODE,
      name: "Congress pass",
      description: "Participation in the European Go Congress 2027.",
      category: "participation",
      vat_category: "reduced",
      position: 0,
      available: true,
      requires_participant: true
    )

    VARIANTS.each_with_index do |variant_config, index|
      variant = MigrationProductVariant.create!(
        product_id: product.id,
        code: variant_config[:code],
        name: variant_config[:name],
        position: index,
        available: true
      )

      variant_config[:prices].each do |tier_name, price_cents|
        MigrationPriceTier.create!(
          product_variant_id: variant.id,
          name: tier_name.to_s,
          price_cents: price_cents,
          valid_until: TIER_VALID_UNTIL.fetch(tier_name)
        )
      end
    end

    YOUTH_DISCOUNTS.each do |age_group, discount_fraction|
      MigrationParticipantDiscount.create!(product_id: product.id, age_group: age_group, discount_fraction: discount_fraction)
    end
  end

  def down
    product = MigrationProduct.find_by(code: CODE)
    return unless product

    variant_ids = MigrationProductVariant.where(product_id: product.id).pluck(:id)
    MigrationPriceTier.where(product_variant_id: variant_ids).or(MigrationPriceTier.where(product_id: product.id)).delete_all
    MigrationProductVariant.where(id: variant_ids).delete_all
    MigrationParticipantDiscount.where(product_id: product.id).delete_all
    product.delete
  end
end
