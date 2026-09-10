class DropActionTextTables < ActiveRecord::Migration[8.1]
  class LegacyAttachment < ApplicationRecord
    self.table_name = "active_storage_attachments"
  end

  def up
    LegacyAttachment.where(record_type: "ActionText::RichText").delete_all
    drop_table :action_text_rich_texts
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Dropping Action Text content cannot be reversed"
  end
end
