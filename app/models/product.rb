# == Schema Information
#
# Table name: products
#
#  id               :bigint           not null, primary key
#  productable_type :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  order_id         :bigint           not null
#  productable_id   :bigint           not null
#
# Indexes
#
#  index_products_on_order_id     (order_id) UNIQUE
#  index_products_on_productable  (productable_type,productable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id)
#
class Product < ApplicationRecord
  belongs_to :order, inverse_of: :products
  belongs_to :productable, polymorphic: true

  after_destroy :destroy_order

  validates :productable_type, inclusion: { in: %w[ParticipantTicket HostelBooking] }
  validates :order_id, uniqueness: true, allow_nil: true
  validates :productable_id, uniqueness: { scope: :productable_type }
  validate :links_unchanged, on: :update

  private

  def links_unchanged
    if will_save_change_to_order_id? || will_save_change_to_productable_id? || will_save_change_to_productable_type?
      errors.add(:base, "A product cannot be moved to another order or item")
    end
  end

  def destroy_order
    Order.find(order_id).destroy!
  end
end
