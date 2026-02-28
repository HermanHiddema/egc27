class CreateMenuItems < ActiveRecord::Migration[8.1]
  def change
    create_table :menu_items do |t|
      t.references :menu, null: false, foreign_key: true
      t.references :parent, null: true, foreign_key: { to_table: :menu_items }
      t.references :page, null: true, foreign_key: true
      t.string :label, null: false
      t.string :url
      t.integer :position, null: false, default: 0
      t.boolean :visible, null: false, default: true
      t.boolean :open_in_new_tab, null: false, default: false

      t.timestamps
    end

    add_index :menu_items, [:menu_id, :parent_id, :position]
  end
end
