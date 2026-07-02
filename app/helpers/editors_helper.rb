module EditorsHelper
  SUPPORTED_EDITORS = %w[trix tinymce].freeze
  DEFAULT_FALLBACK_EDITOR = "tinymce".freeze
  TINYMCE_SCRIPT_PATH = "tinymce/js/tinymce/tinymce.min.js".freeze

  # Tags/attributes allowed when rendering stored HTML authored via TinyMCE.
  # Kept intentionally narrow (no scripts, styles or event handlers) to avoid
  # XSS, while still covering the formatting the editor toolbar can produce.
  ALLOWED_HTML_TAGS = %w[
    p br hr h2 h3 h4 blockquote pre code
    strong b em i u s sub sup
    ul ol li a img
    table thead tbody tfoot tr th td caption col colgroup
    figure figcaption
  ].freeze
  ALLOWED_HTML_ATTRIBUTES = %w[href src alt title rel colspan rowspan scope class width height].freeze

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

  def tinymce_script_url
    asset_path(TINYMCE_SCRIPT_PATH)
  end

  # Prefer TinyMCE-native HTML when present; otherwise prefill from the
  # ActionText body so switching editor modes still shows existing content.
  def tinymce_content_value(record)
    return "" unless record.respond_to?(:content_html)

    record.content_html.presence || record.content&.body&.to_s
  end

  # Render stored HTML content (authored via TinyMCE) after sanitising it
  # against an explicit allowlist of tags and attributes.
  def render_html_content(html)
    sanitize(html.to_s, tags: ALLOWED_HTML_TAGS, attributes: ALLOWED_HTML_ATTRIBUTES)
  end
end
