class RemoveLegacyContentColumns < ActiveRecord::Migration[8.1]
  def up
    remove_column :articles, :content, :text
    remove_column :pages, :content, :text
  end

  def down
    add_column :articles, :content, :text
    add_column :pages, :content, :text, null: false, default: ""
  end
end
