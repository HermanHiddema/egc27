require "net/http"
require "json"

class CloudflareTurnstileService
  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  # Verifies a Cloudflare Turnstile token.
  # Both CLOUDFLARE_TURNSTILE_SECRET_KEY and CLOUDFLARE_TURNSTILE_SITE_KEY must be set
  # for verification to be active. If only one key is configured, a warning is logged and
  # the request is allowed through (to avoid silently blocking all submissions).
  def verify(token:, remote_ip: nil)
    secret_key = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
    site_key = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]

    if secret_key.blank? && site_key.blank?
      return true
    end

    if secret_key.blank? || site_key.blank?
      Rails.logger.warn("Turnstile misconfiguration: both CLOUDFLARE_TURNSTILE_SECRET_KEY and CLOUDFLARE_TURNSTILE_SITE_KEY must be set. Skipping verification.")
      return true
    end

    return false if token.blank?

    body = { "secret" => secret_key, "response" => token.to_s }
    body["remoteip"] = remote_ip.to_s if remote_ip.present?

    uri = URI(VERIFY_URL)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.open_timeout = 5
      http.read_timeout = 10
      http.post(uri.path, URI.encode_www_form(body), "Content-Type" => "application/x-www-form-urlencoded")
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("Turnstile verification non-success status=#{response.code}")
      return false
    end

    JSON.parse(response.body)["success"] == true
  rescue StandardError => e
    Rails.logger.warn("Turnstile verification error: #{e.class}")
    false
  end
end
