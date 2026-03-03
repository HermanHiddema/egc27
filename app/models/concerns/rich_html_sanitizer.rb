module RichHtmlSanitizer
  ALLOWED_TAGS = %w[
    p br div span
    strong em u s
    h1 h2 h3 h4 h5 h6
    ul ol li
    a
    blockquote code pre
    hr
    sub sup
  ].freeze

  ALLOWED_ATTRIBUTES = %w[
    href title target rel
    class style
    data-list data-indent data-checked
  ].freeze

  module_function

  def sanitize_html(value)
    ActionController::Base.helpers.sanitize(
      value,
      tags: ALLOWED_TAGS,
      attributes: ALLOWED_ATTRIBUTES
    )
  end
end
