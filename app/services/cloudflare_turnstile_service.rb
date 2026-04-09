require "net/http"
require "json"

class CloudflareTurnstileService
  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  # Verifies a Cloudflare Turnstile token.
  # Returns true immediately when no secret key is configured (e.g. in development/test).
  def verify(token:, remote_ip: nil)
    secret_key = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
    return true if secret_key.blank?
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
