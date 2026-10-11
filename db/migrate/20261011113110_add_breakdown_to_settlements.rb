class AddBreakdownToSettlements < ActiveRecord::Migration[8.1]
  def change
    add_column :settlements, :periods, :jsonb, default: {}, null: false
    add_column :settlements, :refunds, :jsonb, default: [], null: false
    add_column :settlements, :chargebacks, :jsonb, default: [], null: false
  end
end
