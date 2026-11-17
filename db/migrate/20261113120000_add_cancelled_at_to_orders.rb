class AddCancelledAtToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :cancelled_at, :datetime
  end
end
