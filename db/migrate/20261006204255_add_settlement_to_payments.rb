class AddSettlementToPayments < ActiveRecord::Migration[8.1]
  def change
    add_reference :payments, :settlement, foreign_key: true
  end
end
