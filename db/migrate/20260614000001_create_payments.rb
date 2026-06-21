class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :participant, null: false, foreign_key: true
      t.string :mollie_payment_id
      t.string :status, null: false, default: "open"
      t.integer :amount_cents, null: false
      t.string :description, null: false

      t.timestamps
    end

    add_index :payments, :mollie_payment_id, unique: true
    add_index :payments, :status
  end
end
