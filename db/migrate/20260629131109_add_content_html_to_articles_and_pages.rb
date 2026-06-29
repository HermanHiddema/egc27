class AddContentHtmlToArticlesAndPages < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :content_html, :text
    add_column :pages, :content_html, :text
  end
end
