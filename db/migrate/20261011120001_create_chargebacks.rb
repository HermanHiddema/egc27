class CreateChargebacks < ActiveRecord::Migration[8.1]
  def change
    create_table :chargebacks do |t|
      t.references :settlement, null: false, foreign_key: true
      t.references :payment, foreign_key: { on_delete: :nullify }
      t.string :mollie_chargeback_id, null: false, index: { unique: true }
      t.string :mollie_payment_id
      t.integer :amount_cents
      t.integer :settlement_amount_cents
      t.datetime :mollie_created_at
      t.datetime :reversed_at
      t.timestamps
    end
  end
end
