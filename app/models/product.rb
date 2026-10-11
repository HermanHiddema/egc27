# Something that can be sold in the shop, such as the congress pass, a room or
# a T-shirt. A product either has its own price tiers, or one or more variants
# that each have their own price tiers (e.g. the attendance options of the
# congress pass). Prices are VAT inclusive; the VAT category determines the
# VAT rate included in them.
# == Schema Information
#
# Table name: products
#
#  id                   :bigint           not null, primary key
#  available            :boolean          default(TRUE), not null
#  category             :string           not null
#  code                 :string
#  description          :text
#  name                 :string           not null
#  position             :integer          default(0), not null
#  requires_participant :boolean          default(FALSE), not null
#  vat_category         :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_products_on_category  (category)
#  index_products_on_code      (code) UNIQUE
#
class Product < ApplicationRecord
  include PriceTierOwner

  CATEGORIES = %w[participation accommodation merchandise meal_voucher other].freeze
  VAT_RATES = {
    "standard" => BigDecimal("0.21"),
    "reduced" => BigDecimal("0.09"),
    "zero" => BigDecimal("0"),
    "exempt" => BigDecimal("0")
  }.freeze
  VAT_CATEGORIES = VAT_RATES.keys.freeze

  has_paper_trail

  has_many :variants, -> { order(:position, :id) }, class_name: "ProductVariant", inverse_of: :product, dependent: :destroy
  has_many :price_tiers, -> { order(Arel.sql("valid_until ASC NULLS LAST")) }, inverse_of: :product, dependent: :destroy
  has_many :participant_discounts, inverse_of: :product, dependent: :destroy

  scope :available, -> { where(available: true) }
  scope :ordered, -> { order(:position, :name) }

  validates :name, presence: true
  validates :code, uniqueness: true, allow_nil: true
  validates :category, inclusion: { in: CATEGORIES, message: "must be selected" }
  validates :vat_category, inclusion: { in: VAT_CATEGORIES, message: "must be selected" }
  validates :position, numericality: { only_integer: true }

  normalizes :code, with: ->(code) { code.strip.presence }

  def vat_rate
    VAT_RATES.fetch(vat_category)
  end

  # The discount fraction (between 0 and 1) that applies to the given
  # participant, based on their age group.
  def discount_fraction_for(participant)
    return BigDecimal("0") if participant&.age_group.blank?

    participant_discounts.find { |discount| discount.age_group == participant.age_group }&.discount_fraction || BigDecimal("0")
  end
end
