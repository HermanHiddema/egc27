# A variant of a product with its own price tiers, e.g. an attendance option
# of the congress pass or a size of a T-shirt.
# == Schema Information
#
# Table name: product_variants
#
#  id         :bigint           not null, primary key
#  available  :boolean          default(TRUE), not null
#  code       :string
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  product_id :bigint           not null
#
# Indexes
#
#  index_product_variants_on_product_id           (product_id)
#  index_product_variants_on_product_id_and_code  (product_id,code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (product_id => products.id)
#
class ProductVariant < ApplicationRecord
  include PriceTierOwner

  has_paper_trail

  belongs_to :product, inverse_of: :variants
  has_many :price_tiers, -> { order(Arel.sql("valid_until ASC NULLS LAST")) }, inverse_of: :product_variant, dependent: :destroy

  scope :available, -> { where(available: true) }

  validates :name, presence: true
  validates :code, uniqueness: { scope: :product_id }, allow_nil: true
  validates :position, numericality: { only_integer: true }

  normalizes :code, with: ->(code) { code.strip.presence }
end
