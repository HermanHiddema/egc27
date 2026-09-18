require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "sends a Content-Security-Policy header with the key directives" do
    get new_user_session_path

    assert_response :success

    header = response.headers["Content-Security-Policy"]
    assert header.present?, "expected a Content-Security-Policy header to be sent"

    directives = header.split(";").map(&:strip)

    assert_includes directives, "default-src 'self'"
    assert_includes directives, "object-src 'none'"
    assert_includes directives, "base-uri 'self'"
    assert_includes directives, "form-action 'self'"
    assert_includes directives, "frame-ancestors 'none'"
    assert_includes directives, "frame-src 'self' https://challenges.cloudflare.com"
    assert_includes directives, "font-src 'self' data:"
    assert_includes directives, "img-src 'self' data: blob: https:"

    connect_src = directives.find { |directive| directive.start_with?("connect-src ") }
    assert_includes connect_src, "'self'"
    egd_connect_origins.each { |origin| assert_includes connect_src, origin }

    script_src = directives.find { |directive| directive.start_with?("script-src ") }
    assert_includes script_src, "'self'"
    assert_includes script_src, "https://challenges.cloudflare.com"
    assert_match(/'nonce-[^']+'/, script_src)
    assert_not_includes script_src, "'unsafe-inline'"

    style_src = directives.find { |directive| directive.start_with?("style-src ") }
    assert_includes style_src, "'self'"
    assert_includes style_src, "https://cdn.jsdelivr.net"
  end

  test "nonces inline scripts emitted by the importmap tags" do
    get new_user_session_path

    assert_response :success

    nonce = response.headers["Content-Security-Policy"][/script-src[^;]*'nonce-([^']+)'/, 1]
    assert nonce.present?

    assert_select "script[type='importmap'][nonce=?]", nonce
  end

  test "nonces the turnstile inline callback when the widget is rendered" do
    with_turnstile_configured do
      get new_user_session_path

      assert_response :success

      nonce = response.headers["Content-Security-Policy"][/script-src[^;]*'nonce-([^']+)'/, 1]
      assert nonce.present?

      turnstile_callback = css_select("script[nonce='#{nonce}']").find do |script|
        script.text.include?("egc27TurnstileOnLoad")
      end

      assert turnstile_callback.present?, "expected the Turnstile inline callback to carry the CSP nonce"
    end
  end

  private

  def egd_connect_origins
    [
      ENV.fetch("EGD_API_URL", "https://europeangodatabase.eu/EGD/GetPlayerDataByData.php"),
      ENV.fetch("EGD_PIN_API_URL", "https://europeangodatabase.eu/EGD/GetPlayerDataByPIN.php")
    ].filter_map do |url|
      uri = URI.parse(url)
      uri.origin if uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      nil
    end.uniq
  end
end
