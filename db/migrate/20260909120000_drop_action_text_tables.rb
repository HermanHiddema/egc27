require "cgi"

class DropActionTextTables < ActiveRecord::Migration[8.1]
  class LegacyArticle < ApplicationRecord
    self.table_name = "articles"
  end

  class LegacyPage < ApplicationRecord
    self.table_name = "pages"
  end

  class LegacyRichText < ApplicationRecord
    self.table_name = "action_text_rich_texts"
  end

  class LegacyAttachment < ApplicationRecord
    self.table_name = "active_storage_attachments"
  end

  ACTIVE_STORAGE_URL_PATTERN = %r{/rails/active_storage/(?:blobs|representations)(?:/(?:redirect|proxy))?/([^/?"'<>]+)}.freeze

  def up
    reconcile_content_html!
    migrate_embed_attachments!
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

  private

  def reconcile_content_html!
    say_with_time "Reconciling Action Text content_html" do
      LegacyRichText.where(record_type: %w[Article Page], name: "content").find_each do |rich_text|
        next if rich_text.body.blank?

        record = find_record!(rich_text)
        next if record.content_html.present?

        record.update_columns(
          content_html: rich_text.body.to_s,
          updated_at: [record.updated_at, rich_text.updated_at].compact.max || Time.current
        )
      end
    end
  end

  def migrate_embed_attachments!
    say_with_time "Migrating Action Text embed attachments" do
      LegacyRichText.where(record_type: %w[Article Page]).find_each do |rich_text|
        record = find_record!(rich_text)
        attachment_scope = LegacyAttachment.where(record_type: "ActionText::RichText", record_id: rich_text.id)
        next unless attachment_scope.exists?

        referenced_blob_ids = referenced_blob_ids_for(record.content_html)

        attachment_scope.find_each do |attachment|
          next unless referenced_blob_ids.include?(attachment.blob_id)

          LegacyAttachment.find_or_create_by!(
            record_type: rich_text.record_type,
            record_id: rich_text.record_id,
            name: "content_html_embeds",
            blob_id: attachment.blob_id
          ) do |rehome|
            rehome.created_at = attachment.created_at
          end
        end

        attachment_scope.delete_all
      end
    end
  end

  def find_record!(rich_text)
    model_class = rich_text.record_type == "Article" ? LegacyArticle : LegacyPage
    model_class.find_by(id: rich_text.record_id) || raise(
      ActiveRecord::IrreversibleMigration,
      "Cannot migrate #{rich_text.record_type}##{rich_text.record_id} Action Text content"
    )
  end

  def referenced_blob_ids_for(html)
    decoded_html = CGI.unescapeHTML(html.to_s)

    (
      signed_blob_ids_from_urls(decoded_html).filter_map { |signed_id| find_blob_id_by_signed_id(signed_id) } +
      signed_blob_ids_from_sgids(decoded_html).filter_map { |sgid| find_blob_id_by_sgid(sgid) }
    ).uniq
  end

  def signed_blob_ids_from_urls(html)
    html.scan(ACTIVE_STORAGE_URL_PATTERN).flatten
  end

  def signed_blob_ids_from_sgids(html)
    html.scan(/\bsgid=(['"])([^'"]+)\1/).map(&:last) +
      html.scan(/"sgid":"([^"]+)"/).flatten
  end

  def find_blob_id_by_signed_id(signed_id)
    ActiveStorage::Blob.find_signed!(signed_id).id
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    nil
  end

  def find_blob_id_by_sgid(sgid)
    attachable = GlobalID::Locator.locate_signed(sgid, for: "attachable") || GlobalID::Locator.locate_signed(sgid)

    case attachable
    when ActiveStorage::Blob
      attachable.id
    else
      attachable&.respond_to?(:blob) ? attachable.blob&.id : nil
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    nil
  end
end
