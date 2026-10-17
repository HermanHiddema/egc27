# A discount on a product for participants in an age group, expressed as a
# fraction of the price (e.g. 0.5 for 50% off).
# == Schema Information
#
# Table name: participant_discounts
#
#  id                :bigint           not null, primary key
#  age_group         :string           not null
#  discount_fraction :decimal(5, 4)    not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  product_id        :bigint           not null
#
# Indexes
#
#  index_participant_discounts_on_product_id_and_age_group  (product_id,age_group) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (product_id => products.id)
#
class ParticipantDiscount < ApplicationRecord
  has_paper_trail

  belongs_to :product, inverse_of: :participant_discounts

  validates :age_group, inclusion: { in: Participant::AGE_GROUPS, message: "must be selected" },
                        uniqueness: { scope: :product_id }
  validates :discount_fraction, numericality: { greater_than: 0, less_than_or_equal_to: 1 }
end
