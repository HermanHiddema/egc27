class BackfillContentHtml < ActiveRecord::Migration[8.1]
  class LegacyRichText < ApplicationRecord
    self.table_name = "action_text_rich_texts"
  end

  def up
    backfill_records("articles", "Article")
    backfill_records("pages", "Page")
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Content HTML backfill cannot be reversed safely"
  end

  private

  def backfill_records(table_name, record_type)
    say_with_time "Backfilling content_html for #{record_type}" do
      rich_texts = LegacyRichText.where(record_type: record_type, name: "content")

      rich_texts.find_each do |rich_text|
        next if rich_text.body.blank?

        execute(<<~SQL.squish)
          UPDATE #{quote_table_name(table_name)}
          SET content_html = #{quote(rich_text.body)}
          WHERE id = #{quote(rich_text.record_id)}
            AND (content_html IS NULL OR content_html = '')
        SQL
      end
    end
  end
end
