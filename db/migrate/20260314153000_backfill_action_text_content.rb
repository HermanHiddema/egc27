class BackfillActionTextContent < ActiveRecord::Migration[8.1]
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
    raise ActiveRecord::IrreversibleMigration, "Action Text content backfill cannot be reversed safely"
  end

  private

  def backfill_records(model_class, record_type)
    say_with_time "Backfilling Action Text content for #{record_type}" do
      model_class.where.not(content: [nil, ""]).find_each do |record|
        rich_text = LegacyRichText.find_or_initialize_by(
          record_type: record_type,
          record_id: record.id,
          name: "content"
        )

        next if rich_text.persisted? && rich_text.body.present?

        timestamp = record.respond_to?(:updated_at) && record.updated_at.present? ? record.updated_at : Time.current
        rich_text.body = record.content
        rich_text.created_at ||= record.respond_to?(:created_at) && record.created_at.present? ? record.created_at : timestamp
        rich_text.updated_at = timestamp
        rich_text.save!
      end
    end
  end
end
