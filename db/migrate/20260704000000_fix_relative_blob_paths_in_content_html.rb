class FixRelativeBlobPathsInContentHtml < ActiveRecord::Migration[8.1]
  class LegacyArticle < ApplicationRecord
    self.table_name = "articles"
  end

  class LegacyPage < ApplicationRecord
    self.table_name = "pages"
  end

  # Matches double-quoted attribute values that are relative paths pointing at
  # Active Storage, e.g. src="../../rails/active_storage/blobs/..."
  # Captures the one-or-more leading "../" segments separately so they can be
  # dropped and the path rewritten as root-relative.
  RELATIVE_BLOB_PATTERN = /="(?:\.\.\/)+rails\/active_storage\/([^"]+)"/

  def up
    fix_records(LegacyArticle)
    fix_records(LegacyPage)
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Cannot safely reverse blob path normalisation"
  end

  private

  def fix_records(model_class)
    say_with_time "Fixing relative blob paths in #{model_class.table_name}" do
      model_class.where("content_html LIKE '%../rails/active_storage/%'").find_each do |record|
        updated = record.content_html.gsub(RELATIVE_BLOB_PATTERN) do
          "=\"/rails/active_storage/#{Regexp.last_match(1)}\""
        end
        record.update_columns(content_html: updated) if updated != record.content_html
      end
    end
  end
end
