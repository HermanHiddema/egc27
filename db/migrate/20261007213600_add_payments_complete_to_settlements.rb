class AddPaymentsCompleteToSettlements < ActiveRecord::Migration[8.1]
  def change
    add_column :settlements, :payments_complete, :boolean, default: false, null: false
  end
end
