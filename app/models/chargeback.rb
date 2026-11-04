# == Schema Information
#
# Table name: chargebacks
#
#  id                      :bigint           not null, primary key
#  amount_cents            :integer
#  mollie_created_at       :datetime
#  reversed_at             :datetime
#  settlement_amount_cents :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  mollie_chargeback_id    :string           not null
#  mollie_payment_id       :string
#  payment_id              :bigint
#  settlement_id           :bigint           not null
#
# Indexes
#
#  index_chargebacks_on_mollie_chargeback_id  (mollie_chargeback_id) UNIQUE
#  index_chargebacks_on_payment_id            (payment_id)
#  index_chargebacks_on_settlement_id         (settlement_id)
#
# Foreign Keys
#
#  fk_rails_...  (payment_id => payments.id) ON DELETE => nullify
#  fk_rails_...  (settlement_id => settlements.id)
#
# A chargeback that Mollie deducted from a settlement. Chargebacks are synced
# from the Mollie Settlements API by MollieSettlementSync and linked to our own
# payment when it is known here; chargebacks of payments made in another
# webshop only keep the Mollie payment ID.
class Chargeback < ApplicationRecord
  belongs_to :settlement
  belongs_to :payment, optional: true

  validates :mollie_chargeback_id, presence: true, uniqueness: true

  def reversed?
    reversed_at.present?
  end
end
