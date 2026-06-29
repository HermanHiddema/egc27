module EditorsHelper
  SUPPORTED_EDITORS = %w[trix tinymce].freeze
  DEFAULT_FALLBACK_EDITOR = "trix".freeze

  # Tags/attributes allowed when rendering stored HTML authored via TinyMCE.
  # Kept intentionally narrow (no scripts, styles or event handlers) to avoid
  # XSS, while still covering the formatting the editor toolbar can produce.
  ALLOWED_HTML_TAGS = %w[
    p br hr h1 h2 h3 h4 h5 h6 blockquote pre code
    strong b em i u s sub sup
    ul ol li a img
    table thead tbody tfoot tr th td caption col colgroup
  ].freeze
  ALLOWED_HTML_ATTRIBUTES = %w[href src alt title target rel colspan rowspan scope].freeze

  # Editor selected for the current request. Honours an explicit `?editor=`
  # URL param (when it names a supported editor) and otherwise falls back to
  # the application default.
  def current_editor
    requested = params[:editor].to_s
    return requested if SUPPORTED_EDITORS.include?(requested)

    default_editor
  end

  # Application-wide default editor, configured via the DEFAULT_EDITOR ENV var.
  def default_editor
    configured = ENV["DEFAULT_EDITOR"].to_s
    SUPPORTED_EDITORS.include?(configured) ? configured : DEFAULT_FALLBACK_EDITOR
  end

  def tinymce_editor?
    current_editor == "tinymce"
  end

  # Render stored HTML content (authored via TinyMCE) after sanitising it
  # against an explicit allowlist of tags and attributes.
  def render_html_content(html)
    sanitize(html.to_s, tags: ALLOWED_HTML_TAGS, attributes: ALLOWED_HTML_ATTRIBUTES)
  end
end
