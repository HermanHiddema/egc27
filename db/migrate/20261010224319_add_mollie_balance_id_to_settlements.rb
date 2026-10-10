class AddMollieBalanceIdToSettlements < ActiveRecord::Migration[8.1]
  def change
    add_column :settlements, :mollie_balance_id, :string
  end
end
