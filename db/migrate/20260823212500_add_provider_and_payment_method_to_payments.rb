class AddProviderAndPaymentMethodToPayments < ActiveRecord::Migration[8.1]
  def change
    # The provider records who handled the payment, so payments received outside
    # of Mollie (e.g. cash or a bank transfer) can be recorded by an admin.
    add_column :payments, :provider, :string, null: false, default: "mollie"
    # The payment method is the actual means of payment, which also applies to
    # Mollie payments (e.g. ideal or creditcard).
    add_column :payments, :payment_method, :string
    add_column :payments, :reference, :string
    add_index :payments, :provider
  end
end
