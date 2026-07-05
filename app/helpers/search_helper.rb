module SearchHelper
  # Returns a hash of display attributes for a PgSearch::Document.
  # Keys: :title, :url, :type_label, :snippet, :external
  def search_result_attributes(document)
    record = document.searchable
    return nil unless record

    case document.searchable_type
    when "Page"
      {
        title: record.title,
        url: page_path(record),
        type_label: "Page",
        snippet: truncate(strip_tags(record.content_html.to_s), length: 160),
        external: false
      }
    when "Article"
      {
        title: record.title,
        url: article_path(record),
        type_label: "News",
        snippet: truncate(strip_tags(record.content_html.to_s), length: 160),
        external: false
      }
    when "Sponsor"
      {
        title: record.name,
        url: record.website.presence,
        type_label: "Sponsor",
        snippet: truncate(record.description.to_s, length: 160),
        external: true
      }
    end
  end
end
