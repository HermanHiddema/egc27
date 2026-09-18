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
    assert_includes directives, "connect-src 'self'"
    assert_includes directives, "font-src 'self' data:"
    assert_includes directives, "img-src 'self' data: blob: https:"

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
end
