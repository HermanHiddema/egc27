class ConstrainOrderStatus < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :orders, "status IN ('draft', 'submitted')", name: "orders_status_valid"
  end
end
