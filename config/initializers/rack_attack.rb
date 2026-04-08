Rack::Attack.cache.store = Rails.cache

class Rack::Attack
  ### Throttle public endpoints that trigger emails ###

  # Magic link requests: limit by IP address (10 per minute)
  throttle("magic_link/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/users/magic_link" && req.post?
  end

  # Magic link requests: limit by email address (5 per 5 minutes)
  throttle("magic_link/email", limit: 5, period: 5.minutes) do |req|
    if req.path == "/users/magic_link" && req.post?
      email = req.params.dig("user", "email").to_s.strip.downcase
      email unless email.empty?
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

  ### Response for throttled requests ###

  self.throttled_responder = lambda do |env|
    [
      429,
      { "Content-Type" => "text/plain" },
      ["Too many requests. Please try again later.\n"]
    ]
  end
end
