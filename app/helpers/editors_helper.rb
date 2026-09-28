module EditorsHelper
  TINYMCE_SCRIPT_PATH = "tinymce/js/tinymce/tinymce.min.js".freeze

  # Tags/attributes allowed when rendering stored HTML authored via TinyMCE.
  # Kept intentionally narrow (no scripts, styles or event handlers) to avoid
  # XSS, while still covering the formatting the editor toolbar can produce.
  ALLOWED_HTML_TAGS = %w[
    div span p br hr h1 h2 h3 h4 h5 h6 blockquote pre code
    strong b em i u s sub sup
    ul ol li a img
    table thead tbody tfoot tr th td caption col colgroup
    figure figcaption
  ].freeze
  ALLOWED_HTML_ATTRIBUTES = %w[
    href src alt title rel
    colspan rowspan scope class width height
    style align valign bgcolor bordercolor
    border cellpadding cellspacing frame rules
  ].freeze

  def tinymce_script_url
    "/#{TINYMCE_SCRIPT_PATH}"
  end

  # Render stored HTML content (authored via TinyMCE) after sanitising it
  # against an explicit allowlist of tags and attributes.
  def render_html_content(html)
    sanitize(html.to_s, tags: ALLOWED_HTML_TAGS, attributes: ALLOWED_HTML_ATTRIBUTES)
  end
end
