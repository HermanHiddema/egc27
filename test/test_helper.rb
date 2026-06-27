ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
    alias_method :devise_sign_in, :sign_in

    def sign_in(user)
      post user_session_path, params: {
        user: { email: user.email, password: "password123" }
      }
    end

    # Runs the block with Cloudflare Turnstile configured (both keys present) so
    # that controllers including TurnstileVerifiable actually enforce the check.
    def with_turnstile_configured
      previous_secret = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
      previous_site = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
      ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = "test-secret-key"
      ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = "1x00000000000000000000AA"
      yield
    ensure
      if previous_secret.nil?
        ENV.delete("CLOUDFLARE_TURNSTILE_SECRET_KEY")
      else
        ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = previous_secret
      end
      if previous_site.nil?
        ENV.delete("CLOUDFLARE_TURNSTILE_SITE_KEY")
      else
        ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = previous_site
      end
    end
  end
end
