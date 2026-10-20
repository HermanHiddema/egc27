class AddPaymentDateToPayments < ActiveRecord::Migration[8.1]
  def up
    add_column :payments, :payment_date, :date

    execute <<~SQL
      UPDATE payments SET payment_date = created_at::date
    SQL
  end

  def down
    remove_column :payments, :payment_date
  end
end
