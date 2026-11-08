# == Schema Information
#
# Table name: orders
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Order < ApplicationRecord
  has_many :products, dependent: :restrict_with_error, inverse_of: :order
  has_many :payments, dependent: :destroy

  validates :products, length: { minimum: 1 }

  def amount_cents
    products.sum { |product| product.amount_cents.to_i }
  end

  def amount_cents_for_payment(date: Date.current)
    products.sum { |product| product.amount_cents_for_payment(date: date).to_i }
  end

  # A registration without payment attempts can still carry a price from an
  # earlier tier. Once an attempt exists, its product prices must stay fixed.
  def refresh_unattempted_ticket_prices!
    with_lock do
      next if payments.exists?

      products.includes(:productable).each do |product|
        ticket = product.productable
        ticket.update!(price_cents: ticket.price_for) if ticket.is_a?(ParticipantTicket)
      end
    end
  end

  def successful_payment
    candidates = if payments.loaded?
      payments.sort_by { |payment| [payment.created_at, payment.id] }.reverse
    else
      payments.where(status: "paid").order(created_at: :desc, id: :desc)
    end

    candidates.detect(&:valid_full_payment?)
  end

  def paid?
    successful_payment.present?
  end
end
