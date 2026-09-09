class DropActionTextTables < ActiveRecord::Migration[8.1]
  # Rich text bodies were copied into the `content_html` columns by earlier
  # backfill migrations, so the Action Text table is no longer used.
  def up
    drop_table :action_text_rich_texts
  end

  def down
    create_table :action_text_rich_texts do |t|
      t.string :name, null: false
      t.text :body
      t.references :record, null: false, polymorphic: true, index: false

      t.timestamps

      t.index [:record_type, :record_id, :name], name: "index_action_text_rich_texts_uniqueness", unique: true
    end
  end
end
