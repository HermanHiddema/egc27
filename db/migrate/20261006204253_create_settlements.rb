class CreateSettlements < ActiveRecord::Migration[8.1]
  def change
    create_table :settlements do |t|
      t.string :mollie_settlement_id, null: false
      t.string :reference
      t.string :status, null: false
      t.integer :amount_cents, null: false, default: 0
      t.datetime :settled_at
      t.datetime :mollie_created_at

      t.timestamps
    end
    add_index :settlements, :mollie_settlement_id, unique: true
  end
end
