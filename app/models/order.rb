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
    Product.where(order_id: id).sum(:price_cents)
  end

  alias amount_cents total_cents

  def closed?
    payments.completed.exists?
  end
end
