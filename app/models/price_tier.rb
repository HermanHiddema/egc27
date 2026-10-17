# A VAT inclusive price of a product or product variant that applies until
# (and including) valid_until. The tier without valid_until is the final tier,
# which applies after all other tiers have ended.
# == Schema Information
#
# Table name: price_tiers
#
#  id                 :bigint           not null, primary key
#  name               :string           not null
#  price_cents        :integer          not null
#  valid_until        :date
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  product_id         :bigint
#  product_variant_id :bigint
#
# Indexes
#
#  index_price_tiers_on_product_id_and_valid_until          (product_id,valid_until) UNIQUE
#  index_price_tiers_on_product_id_final                    (product_id) UNIQUE WHERE (valid_until IS NULL)
#  index_price_tiers_on_product_variant_id_and_valid_until  (product_variant_id,valid_until) UNIQUE
#  index_price_tiers_on_product_variant_id_final            (product_variant_id) UNIQUE WHERE (valid_until IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (product_id => products.id)
#  fk_rails_...  (product_variant_id => product_variants.id)
#
class PriceTier < ApplicationRecord
  has_paper_trail

  belongs_to :product, optional: true, inverse_of: :price_tiers
  belongs_to :product_variant, optional: true, inverse_of: :price_tiers

  validates :name, presence: true
  validates :price_cents, numericality: { only_integer: true, greater_than: 0 }
  validate :belongs_to_exactly_one_owner
  validates :valid_until, uniqueness: { scope: :product_id }, if: :product_id?
  validates :valid_until, uniqueness: { scope: :product_variant_id }, if: :product_variant_id?

  def owner
    product_variant || product
  end

  def final?
    valid_until.nil?
  end

  private

  def belongs_to_exactly_one_owner
    return if product.present? ^ product_variant.present?

    errors.add(:base, "must belong to either a product or a product variant")
  end
end
