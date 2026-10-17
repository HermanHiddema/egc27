class CreateProductCatalogue < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :code, index: { unique: true }
      t.string :name, null: false
      t.text :description
      t.string :category, null: false, index: true
      t.string :vat_category, null: false
      t.integer :position, null: false, default: 0
      t.boolean :available, null: false, default: true
      t.boolean :requires_participant, null: false, default: false
      t.timestamps
    end

    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :code
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :available, null: false, default: true
      t.timestamps
    end
    add_index :product_variants, [:product_id, :code], unique: true

    create_table :price_tiers do |t|
      t.references :product, foreign_key: true, index: false
      t.references :product_variant, foreign_key: true, index: false
      t.string :name, null: false
      t.integer :price_cents, null: false
      t.date :valid_until
      t.timestamps
    end
    add_index :price_tiers, [:product_id, :valid_until], unique: true
    add_index :price_tiers, [:product_variant_id, :valid_until], unique: true
    add_index :price_tiers, :product_id, unique: true, where: "valid_until IS NULL",
                                         name: "index_price_tiers_on_product_id_final"
    add_index :price_tiers, :product_variant_id, unique: true, where: "valid_until IS NULL",
                                                 name: "index_price_tiers_on_product_variant_id_final"
    add_check_constraint :price_tiers, "num_nonnulls(product_id, product_variant_id) = 1",
                         name: "price_tiers_exactly_one_owner"
    add_check_constraint :price_tiers, "price_cents > 0", name: "price_tiers_price_cents_positive"

    create_table :participant_discounts do |t|
      t.references :product, null: false, foreign_key: true, index: false
      t.string :age_group, null: false
      t.decimal :discount_fraction, precision: 5, scale: 4, null: false
      t.timestamps
    end
    add_index :participant_discounts, [:product_id, :age_group], unique: true
    add_check_constraint :participant_discounts, "discount_fraction > 0 AND discount_fraction <= 1",
                         name: "participant_discounts_discount_fraction_range"
  end
end
