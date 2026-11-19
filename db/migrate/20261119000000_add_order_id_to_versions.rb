class AddOrderIdToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :versions, :order_id, :bigint
    add_index :versions, :order_id
  end
end
