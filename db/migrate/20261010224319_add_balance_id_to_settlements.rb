class AddBalanceIdToSettlements < ActiveRecord::Migration[8.1]
  def change
    add_column :settlements, :balance_id, :string
  end
end
