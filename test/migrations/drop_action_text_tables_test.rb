require "test_helper"
require Rails.root.join("db/migrate/20260909120000_drop_action_text_tables").to_s

class DropActionTextTablesTest < ActiveSupport::TestCase
  parallelize(workers: 1)
  self.use_transactional_tests = false

  class LegacyRichText < ApplicationRecord
    self.table_name = "action_text_rich_texts"
  end

  def setup
    super
    @article_ids = []
    @page_ids = []
    @blob_ids = []

    ActiveRecord::Base.connection.drop_table(:action_text_rich_texts, if_exists: true)
    DropActionTextTables.new.migrate(:down)
    LegacyRichText.reset_column_information
  end

  def teardown
    ActiveStorage::Attachment.where(record_type: "ActionText::RichText").delete_all
    ActiveStorage::Attachment.where(name: "content_html_embeds").delete_all
    ActiveStorage::Blob.where(id: @blob_ids).find_each(&:purge)
    Article.where(id: @article_ids).delete_all
    Page.where(id: @page_ids).delete_all
    ActiveRecord::Base.connection.drop_table(:action_text_rich_texts, if_exists: true)
    super
  end

  test "copies newer Action Text content_html and rehomes referenced embeds" do
    article = Article.create!(title: "Migration Article", content_html: "<p>Old</p>", user: users(:admin))
    @article_ids << article.id
    article.update_columns(updated_at: 1.day.ago)

    blob = create_blob(filename: "embedded.png", body: "pngdata", content_type: "image/png")
    rich_text = create_rich_text(
      record_type: "Article",
      record_id: article.id,
      body: %(<p>New</p><img src="/rails/active_storage/blobs/redirect/#{blob.signed_id}/embedded.png">),
      created_at: 2.days.ago,
      updated_at: Time.current
    )
    create_legacy_attachment(rich_text_id: rich_text.id, blob_id: blob.id)

    DropActionTextTables.new.migrate(:up)

    assert_equal rich_text.body, article.reload.content_html
    assert ActiveStorage::Attachment.exists?(
      record_type: "Article",
      record_id: article.id,
      name: "content_html_embeds",
      blob_id: blob.id
    )
    assert_not ActiveStorage::Attachment.exists?(
      record_type: "ActionText::RichText",
      record_id: rich_text.id,
      blob_id: blob.id
    )
  end

  test "keeps newer TinyMCE content_html and removes obsolete legacy embeds" do
    page = Page.create!(title: "Migration Page", content_html: "<p>TinyMCE wins</p>")
    @page_ids << page.id
    page.update_columns(updated_at: Time.current)

    blob = create_blob(filename: "obsolete.png", body: "pngdata", content_type: "image/png")
    rich_text = create_rich_text(
      record_type: "Page",
      record_id: page.id,
      body: "<p>Older Trix</p>",
      created_at: 2.days.ago,
      updated_at: 1.day.ago
    )
    create_legacy_attachment(rich_text_id: rich_text.id, blob_id: blob.id)

    DropActionTextTables.new.migrate(:up)

    assert_equal "<p>TinyMCE wins</p>", page.reload.content_html
    assert_not ActiveStorage::Attachment.exists?(
      record_type: "Page",
      record_id: page.id,
      name: "content_html_embeds",
      blob_id: blob.id
    )
    assert_not ActiveStorage::Attachment.exists?(
      record_type: "ActionText::RichText",
      record_id: rich_text.id,
      blob_id: blob.id
    )
  end

  private

  def create_blob(filename:, body:, content_type:)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(body),
      filename: filename,
      content_type: content_type
    )
    @blob_ids << blob.id
    blob
  end

  def create_rich_text(record_type:, record_id:, body:, created_at:, updated_at:)
    LegacyRichText.create!(
      record_type: record_type,
      record_id: record_id,
      name: "content",
      body: body,
      created_at: created_at,
      updated_at: updated_at
    )
  end

  def create_legacy_attachment(rich_text_id:, blob_id:)
    timestamp = Time.current
    ActiveStorage::Attachment.insert_all!([{
      name: "embeds",
      record_type: "ActionText::RichText",
      record_id: rich_text_id,
      blob_id: blob_id,
      created_at: timestamp
    }])
  end
end
