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

    response = Net::HTTP.post_form(URI(VERIFY_URL), body)
    JSON.parse(response.body)["success"] == true
  rescue StandardError => e
    Rails.logger.warn("Turnstile verification error: #{e.class}")
    false
  end
end
