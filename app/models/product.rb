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

  before_destroy :prevent_removal_from_submitted_order
  before_validation :set_initial_price, on: :create

  validates :productable_type, inclusion: { in: %w[ParticipantTicket HostelBooking] }
  validate :order_must_be_editable, on: :create
  validates :productable_id, uniqueness: { scope: :productable_type }
  validates :price_cents, numericality: { only_integer: true, greater_than: 0 }
  validate :links_unchanged, on: :update
  validate :price_changes_only_when_repricing, on: :update
  validate :productable_belongs_to_order_owner

  def amount_cents
    price_cents
  end

  def reprice!(new_price_cents)
    @repricing = true
    update!(price_cents: new_price_cents)
  ensure
    @repricing = false
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

  def order_must_be_editable
    errors.add(:order, "is not an editable draft") unless order&.editable?
  end

  def productable_belongs_to_order_owner
    owner_id = case productable
    when ParticipantTicket then productable.participant&.user_id
    when HostelBooking then productable.user_id
    end
    errors.add(:order, "must belong to the item's owner") if order && owner_id && order.user_id != owner_id
  end

  def prevent_removal_from_submitted_order
    return if order&.editable?

    errors.add(:order, "products cannot be removed after submission")
    throw :abort
  end
end
