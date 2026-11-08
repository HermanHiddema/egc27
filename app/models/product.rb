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
#  index_products_on_order_id     (order_id)
#  index_products_on_productable  (productable_type,productable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id)
#
class Product < ApplicationRecord
  belongs_to :order, inverse_of: :products
  belongs_to :productable, polymorphic: true

  after_destroy :destroy_order_if_empty
  after_update :destroy_previous_order_if_empty

  validates :productable_type, inclusion: { in: %w[ParticipantTicket HostelBooking] }
  validates :productable_id, uniqueness: { scope: :productable_type }
  validate :cannot_move_order_with_payment_history, on: :update, if: :will_save_change_to_order_id?
  validate :productable_cannot_change, on: :update

  def amount_cents
    productable.amount_cents
  end

  def amount_cents_for_payment(date: Date.current)
    if productable.respond_to?(:price_for)
      productable.price_for(date: date)
    else
      amount_cents
    end
  end

  private

  def productable_cannot_change
    return unless will_save_change_to_productable_id? || will_save_change_to_productable_type?

    errors.add(:base, "A product cannot be moved to another item")
  end

  def cannot_move_order_with_payment_history
    source_has_payments = Order.find_by(id: order_id_in_database)&.payments&.exists?
    destination_has_payments = order&.payments&.exists?
    return unless source_has_payments || destination_has_payments

    errors.add(:order, "cannot change when either order has payment history")
  end

  def destroy_order_if_empty
    destroy_empty_order(order_id)
  end

  def destroy_previous_order_if_empty
    destroy_empty_order(attribute_before_last_save(:order_id))
  end

  def destroy_empty_order(previous_order_id)
    previous_order = Order.find_by(id: previous_order_id)
    previous_order&.destroy! if previous_order&.products&.empty?
  end
end
