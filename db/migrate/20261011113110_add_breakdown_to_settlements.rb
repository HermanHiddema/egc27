class AddBreakdownToSettlements < ActiveRecord::Migration[8.1]
  def change
    add_column :settlements, :periods, :jsonb, default: {}, null: false
    add_column :settlements, :other_payments, :jsonb, default: [], null: false
  end
end
