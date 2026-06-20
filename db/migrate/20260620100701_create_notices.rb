class CreateNotices < ActiveRecord::Migration[8.1]
  def change
    create_table :notices do |t|
      t.string :title, null: false
      t.text :body
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
