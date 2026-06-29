module EditorsHelper
  SUPPORTED_EDITORS = %w[trix tinymce].freeze
  DEFAULT_FALLBACK_EDITOR = "trix".freeze

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

  # Render stored HTML content (authored via TinyMCE) after sanitising it.
  def render_html_content(html)
    sanitize(html.to_s)
  end
end
