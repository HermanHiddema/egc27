module RichTextSearchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model

    multisearchable against: [:title, :searchable_content]
  end

  # Plain-text content used for full-text indexing. Prefers TinyMCE-authored
  # HTML and falls back to the legacy Action Text body, with markup stripped.
  def searchable_content
    ApplicationController.helpers.strip_tags(content_html.presence || content&.body&.to_s)
  end
end
