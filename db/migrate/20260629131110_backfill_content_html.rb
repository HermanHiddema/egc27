class BackfillContentHtml < ActiveRecord::Migration[8.1]
  class LegacyArticle < ApplicationRecord
    self.table_name = "articles"
  end

  class LegacyPage < ApplicationRecord
    self.table_name = "pages"
  end

  class LegacyRichText < ApplicationRecord
    self.table_name = "action_text_rich_texts"
  end

  def up
    backfill_records(LegacyArticle, "Article")
    backfill_records(LegacyPage, "Page")
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Content HTML backfill cannot be reversed safely"
  end

  private

  def backfill_records(model_class, record_type)
    say_with_time "Backfilling content_html for #{record_type}" do
      LegacyRichText.where(record_type: record_type, name: "content").find_each do |rich_text|
        next if rich_text.body.blank?

        model_class
          .where(id: rich_text.record_id)
          .where("content_html IS NULL OR content_html = ''")
          .update_all(content_html: rich_text.body)
      end
    end
  end
end
