class CreateNewsletters < ActiveRecord::Migration[8.1]
  def change
    create_table :newsletters do |t|
      t.string :title, null: false
      t.string :subject, null: false
      t.text :content_html, null: false
      t.datetime :sent_at
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :newsletters, :sent_at
  end
end
