require "openssl"

# Use the shared Rails cache for throttle counters so limits apply consistently
# across all Puma workers and app replicas.
Rack::Attack.cache.store = Rails.cache

class Rack::Attack
  ### Throttle public endpoints that trigger emails ###

  # Match a path exactly while also accepting an optional Rails format suffix
  # (e.g. .json) and an optional trailing slash so throttles cannot be bypassed.
  MAGIC_LINK_PATH          = %r{\A/users/magic_link(\.[^/]+)?/?\z}
  PARTICIPANTS_PATH        = %r{\A/participants(\.[^/]+)?/?\z}
  EGD_REGISTERED_PATH      = %r{\A/participants/egd_registered(\.[^/]+)?/?\z}
  ALTER_REGISTRATION_PATH  = %r{\A/participants/alter_registration(\.[^/]+)?/?\z}
  RESEND_CONFIRMATION_PATH = %r{\A/participants/(?<uuid>[^/]+)/resend_confirmation(\.[^/]+)?/?\z}
  PASSWORD_PATH            = %r{\A/users/password(\.[^/]+)?/?\z}
  CONFIRMATION_PATH        = %r{\A/users/confirmation(\.[^/]+)?/?\z}
  SIGN_IN_PATH             = %r{\A/users/sign_in(\.[^/]+)?/?\z}
  NEWSLETTER_PATH          = %r{\A/newsletter_subscriptions(\.[^/]+)?/?\z}

  # Magic link requests: limit by IP address (10 per minute)
  throttle("magic_link/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.match?(MAGIC_LINK_PATH) && req.post?
  end

  # Magic link requests: limit by email address (5 per 5 minutes)
  # Email is HMAC'd before use as a cache key to avoid persisting PII.
  throttle("magic_link/email", limit: 5, period: 5.minutes) do |req|
    if req.path.match?(MAGIC_LINK_PATH) && req.post?
      email = req.params.dig("user", "email").to_s.strip.downcase
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, email) unless email.empty?
    end
  end

  # Participant registration: limit by IP address (10 per minute)
  throttle("participants/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.match?(PARTICIPANTS_PATH) && req.post?
  end

  # EGD registration lookups: limit by IP address (60 per minute)
  throttle("egd_registered/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.match?(EGD_REGISTERED_PATH) && req.get?
  end

  # Alter-registration lookups: limit by IP address (20 per minute)
  throttle("alter_registration/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.path.match?(ALTER_REGISTRATION_PATH) && req.get?
  end

  # Confirmation email resend: limit by participant UUID (2 per minute)
  throttle("resend_confirmation/uuid", limit: 2, period: 1.minute) do |req|
    if req.post? && (match = RESEND_CONFIRMATION_PATH.match(req.path))
      match[:uuid]
    end
  end

  # Password reset: limit by IP address (5 per minute)
  throttle("password_reset/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.match?(PASSWORD_PATH) && req.post?
  end

  # Password reset: limit by email address (3 per 5 minutes)
  # Email is HMAC'd before use as a cache key to avoid persisting PII.
  throttle("password_reset/email", limit: 3, period: 5.minutes) do |req|
    if req.path.match?(PASSWORD_PATH) && req.post?
      email = req.params.dig("user", "email").to_s.strip.downcase
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, email) unless email.empty?
    end
  end

  # Confirmation email resend: limit by IP address (5 per minute)
  throttle("confirmation/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.match?(CONFIRMATION_PATH) && req.post?
  end

  # Sign in attempts: limit by IP address (10 per minute)
  throttle("login/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.match?(SIGN_IN_PATH) && req.post?
  end

  # Sign in attempts: limit by email address (5 per 5 minutes) to slow down
  # targeted credential-stuffing. Email is HMAC'd before use as a cache key to
  # avoid persisting PII.
  throttle("login/email", limit: 5, period: 5.minutes) do |req|
    if req.path.match?(SIGN_IN_PATH) && req.post?
      email = req.params.dig("user", "email").to_s.strip.downcase
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, email) unless email.empty?
    end
  end

  # Newsletter subscription: limit by IP address (10 per minute)
  throttle("newsletter/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.match?(NEWSLETTER_PATH) && req.post?
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
