class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :orderable, polymorphic: true
      t.string :description, null: false
      t.integer :amount_cents, null: false
      t.string :status, null: false, default: "cart"
      t.string :mollie_payment_id
      t.string :checkout_reference
      t.datetime :paid_at

      t.timestamps
    end

    add_index :orders, :status
    add_index :orders, :mollie_payment_id
    add_index :orders, :checkout_reference
  end
end
