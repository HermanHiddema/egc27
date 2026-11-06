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
end
