# == Schema Information
#
# Table name: participant_tickets
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  participant_id :bigint           not null
#
# Indexes
#
#  index_participant_tickets_on_participant_id  (participant_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (participant_id => participants.id)
#
class ParticipantTicket < ApplicationRecord
  belongs_to :participant, inverse_of: :participant_ticket
  has_one :product, as: :productable, dependent: :destroy
  has_one :order, through: :product
  has_many :payments, through: :order

  validate :participant_is_player, on: :create

  after_create :create_order_and_product!

  # A new payment attempt uses the tier in effect on that date.
  def price_for(date: Date.current)
    CongressPassPricing.new(attendance_option: participant.attendance_option, age_group: participant.age_group, payment_date: date).price_cents
  end

  # Compatibility reader; Product is the sole persisted price authority.
  def price_cents
    product&.price_cents
  end

  private

  def participant_is_player
    errors.add(:participant, "must be a player") if participant && !participant.player?
  end

  def create_order_and_product!
    Order.create!(products: [Product.new(productable: self)])
  end
end
