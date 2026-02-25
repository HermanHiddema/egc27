class RenameNewsToArticles < ActiveRecord::Migration[8.1]
  def change
    rename_table :news, :articles
  end
end