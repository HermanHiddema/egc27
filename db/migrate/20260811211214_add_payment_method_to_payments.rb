class AddPaymentMethodToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :payment_method, :string, null: false, default: "mollie"
    add_column :payments, :reference, :string
  end
end
