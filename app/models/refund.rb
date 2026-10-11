# == Schema Information
#
# Table name: refunds
#
#  id                      :bigint           not null, primary key
#  amount_cents            :integer
#  description             :string
#  mollie_created_at       :datetime
#  settlement_amount_cents :integer
#  status                  :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  mollie_payment_id       :string
#  mollie_refund_id        :string           not null
#  payment_id              :bigint
#  settlement_id           :bigint           not null
#
# Indexes
#
#  index_refunds_on_mollie_refund_id  (mollie_refund_id) UNIQUE
#  index_refunds_on_payment_id        (payment_id)
#  index_refunds_on_settlement_id     (settlement_id)
#
# Foreign Keys
#
#  fk_rails_...  (payment_id => payments.id) ON DELETE => nullify
#  fk_rails_...  (settlement_id => settlements.id)
#
# A refund by Mollie that was deducted from a settlement. Refunds are synced
# from the Mollie Settlements API by MollieSettlementSync and linked to our own
# payment when it is known here; refunds of payments made in another webshop
# only keep the Mollie payment ID.
class Refund < ApplicationRecord
  belongs_to :settlement
  belongs_to :payment, optional: true

  validates :mollie_refund_id, presence: true, uniqueness: true
end
