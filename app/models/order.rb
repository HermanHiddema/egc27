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

  validates :products, length: { is: 1 }

  def total_cents
    if products.loaded?
      products.sum(&:amount_cents)
    else
      products.sum(:price_cents)
    end
  end

  alias amount_cents total_cents

  def amount_cents_for_payment(date: Date.current)
    products.sum { |product| product.amount_cents_for_payment(date: date).to_i }
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

  def closed?
    payments.completed.exists?
  end
end
