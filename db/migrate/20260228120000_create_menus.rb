class CreateMenus < ActiveRecord::Migration[8.1]
  def change
    create_table :menus do |t|
      t.string :name, null: false
      t.string :location, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :menus, :location, unique: true
  end
end
