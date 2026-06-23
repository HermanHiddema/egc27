class AddConfirmationSentToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :confirmation_sent, :boolean, default: false, null: false
  end
end
