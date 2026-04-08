require "digest"

Rack::Attack.cache.store = Rails.cache

class Rack::Attack
  ### Throttle public endpoints that trigger emails ###

  # Magic link requests: limit by IP address (10 per minute)
  throttle("magic_link/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/users/magic_link" && req.post?
  end

  # Magic link requests: limit by email address (5 per 5 minutes)
  # Email is hashed before use as a cache key to avoid persisting PII.
  throttle("magic_link/email", limit: 5, period: 5.minutes) do |req|
    if req.path == "/users/magic_link" && req.post?
      email = req.params.dig("user", "email").to_s.strip.downcase
      Digest::SHA256.hexdigest(email) unless email.empty?
    end
  end

  # Participant registration: limit by IP address (10 per minute)
  throttle("participants/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/participants" && req.post?
  end

  # Sign-up: limit by IP address (10 per minute)
  throttle("sign_up/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/users" && req.post?
  end

  # Password reset: limit by IP address (5 per minute)
  throttle("password_reset/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  # Password reset: limit by email address (3 per 5 minutes)
  # Email is hashed before use as a cache key to avoid persisting PII.
  throttle("password_reset/email", limit: 3, period: 5.minutes) do |req|
    if req.path == "/users/password" && req.post?
      email = req.params.dig("user", "email").to_s.strip.downcase
      Digest::SHA256.hexdigest(email) unless email.empty?
    end
  end

  # Confirmation email resend: limit by IP address (5 per minute)
  throttle("confirmation/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/users/confirmation" && req.post?
  end

  ### Response for throttled requests ###

  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"] || {}
    period = match_data[:period].to_i
    epoch_time = match_data[:epoch_time].to_i

    retry_after =
      if period.positive? && epoch_time.positive?
        remaining = period - (epoch_time % period)
        remaining.positive? ? remaining : period
      else
        60
      end

    [
      429,
      {
        "Content-Type" => "text/plain",
        "Retry-After" => retry_after.to_s
      },
      ["Too many requests. Please try again later.\n"]
    ]
  end
end
