class AddProductPriceSnapshotToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :product_prices_cents, :jsonb
  end
end
