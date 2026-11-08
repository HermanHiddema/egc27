class AllowMultipleProductsPerOrder < ActiveRecord::Migration[8.1]
  def up
    remove_index :products, :order_id
    add_index :products, :order_id
  end

  def down
    multiple_product_order_ids = select_values(<<~SQL)
      SELECT order_id FROM products GROUP BY order_id HAVING COUNT(*) > 1
    SQL
    if multiple_product_order_ids.any?
      raise ActiveRecord::IrreversibleMigration,
        "Orders with multiple products cannot be represented by the previous schema: #{multiple_product_order_ids.join(', ')}"
    end

    remove_index :products, :order_id
    add_index :products, :order_id, unique: true
  end
end
