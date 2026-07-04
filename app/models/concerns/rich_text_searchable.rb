module RichTextSearchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model

    multisearchable against: [:title, :searchable_content]
  end

  # Plain-text content used for full-text indexing. Uses the TinyMCE-authored
  # HTML with markup stripped.
  def searchable_content
    ActionView::Base.full_sanitizer.sanitize(content_html.to_s)
  end
end
