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

  def successful_payment
    payments.where(status: "paid").order(created_at: :desc, id: :desc).detect(&:valid_full_payment?)
  end

  def paid?
    successful_payment.present?
  end
end
