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
    create_action_text_rich_texts_table
    LegacyRichText.reset_column_information
  end

  def teardown
    ActiveStorage::Attachment.where(record_type: "ActionText::RichText").delete_all
    ActiveStorage::Blob.where(id: @blob_ids).find_each(&:purge)
    Article.where(id: @article_ids).delete_all
    Page.where(id: @page_ids).delete_all
    ActiveRecord::Base.connection.drop_table(:action_text_rich_texts, if_exists: true)
    super
  end

  test "removes Action Text attachments without changing article content_html" do
    article = Article.create!(title: "Migration Article", content_html: "<p>TinyMCE wins</p>", user: users(:admin))
    @article_ids << article.id

    blob = create_blob(filename: "embedded.png", body: "pngdata", content_type: "image/png")
    rich_text = create_rich_text(record_type: "Article", record_id: article.id, body: "<p>Trix content</p>")
    create_legacy_attachment(rich_text_id: rich_text.id, blob_id: blob.id)

    DropActionTextTables.new.migrate(:up)

    assert_equal "<p>TinyMCE wins</p>", article.reload.content_html
    assert_not ActiveRecord::Base.connection.data_source_exists?("action_text_rich_texts")
    assert_not ActiveStorage::Attachment.exists?(
      record_type: "ActionText::RichText",
      record_id: rich_text.id,
      blob_id: blob.id
    )
  end

  test "does not backfill blank content_html from Action Text" do
    page = Page.create!(title: "Migration Page", content_html: "<p>Temp</p>")
    @page_ids << page.id
    page.update_columns(content_html: "")

    rich_text = create_rich_text(record_type: "Page", record_id: page.id, body: "<p>Trix only</p>")

    DropActionTextTables.new.migrate(:up)

    assert_equal "", page.reload.content_html
    assert_not ActiveRecord::Base.connection.data_source_exists?("action_text_rich_texts")
    assert_not ActiveStorage::Attachment.exists?(
      record_type: "ActionText::RichText",
      record_id: rich_text.id
    )
  end

  private

  def create_action_text_rich_texts_table
    ActiveRecord::Base.connection.create_table(:action_text_rich_texts) do |t|
      t.string :name, null: false
      t.text :body
      t.references :record, null: false, polymorphic: true, index: false

      t.timestamps

      t.index [:record_type, :record_id, :name], name: "index_action_text_rich_texts_uniqueness", unique: true
    end
  end

  def create_blob(filename:, body:, content_type:)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(body),
      filename: filename,
      content_type: content_type
    )
    @blob_ids << blob.id
    blob
  end

  def create_rich_text(record_type:, record_id:, body:)
    LegacyRichText.create!(
      record_type: record_type,
      record_id: record_id,
      name: "content",
      body: body
    )
  end

  def create_legacy_attachment(rich_text_id:, blob_id:)
    ActiveStorage::Attachment.insert_all!([{
      name: "embeds",
      record_type: "ActionText::RichText",
      record_id: rich_text_id,
      blob_id: blob_id,
      created_at: Time.current
    }])
  end
end
