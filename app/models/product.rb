# == Schema Information
#
# Table name: products
#
#  id               :bigint           not null, primary key
#  price_cents      :integer          not null
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
  before_validation :set_initial_price, on: :create

  validates :productable_type, inclusion: { in: %w[ParticipantTicket HostelBooking] }
  validates :order_id, uniqueness: true, allow_nil: true
  validates :productable_id, uniqueness: { scope: :productable_type }
  validates :price_cents, numericality: { only_integer: true, greater_than: 0 }
  validate :links_unchanged, on: :update
  validate :price_changes_only_when_repricing, on: :update

  def reprice!(new_price_cents)
    @repricing = true
    update!(price_cents: new_price_cents)
  ensure
    @repricing = false
  end

  def amount_cents
    price_cents
  end

  def amount_cents_for_payment(date: Date.current)
    if productable.respond_to?(:price_for)
      productable.price_for(date: date)
    else
      amount_cents
    end
  end

  private

  def set_initial_price
    return if price_cents.present? || productable.blank?

    self.price_cents = case productable
    when ParticipantTicket then productable.price_for
    when HostelBooking then productable.amount_cents
    end
  end

  def links_unchanged
    if will_save_change_to_order_id? || will_save_change_to_productable_id? || will_save_change_to_productable_type?
      errors.add(:base, "A product cannot be moved to another order or item")
    end
  end

  def price_changes_only_when_repricing
    return unless will_save_change_to_price_cents? && !@repricing

    errors.add(:price_cents, "can only be changed by the order repricing service")
  end

  def destroy_order
    Order.find(order_id).destroy!
  end
end
