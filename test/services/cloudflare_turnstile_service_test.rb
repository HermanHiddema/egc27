require "test_helper"

class CloudflareTurnstileServiceTest < ActiveSupport::TestCase
  test "skips verification and passes when bot protection is disabled" do
    previous = Rails.configuration.x.bot_protection_enabled
    Rails.configuration.x.bot_protection_enabled = false

    ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = "test-secret-key"
    ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = "1x00000000000000000000AA"

    # A blank token would normally fail verification, but it should be allowed
    # through when bot protection is disabled without any network call.
    assert CloudflareTurnstileService.new.verify(token: nil)
  ensure
    Rails.configuration.x.bot_protection_enabled = previous
    ENV.delete("CLOUDFLARE_TURNSTILE_SECRET_KEY")
    ENV.delete("CLOUDFLARE_TURNSTILE_SITE_KEY")
  end

  test "rejects blank token when bot protection is enabled and keys are set" do
    previous = Rails.configuration.x.bot_protection_enabled
    Rails.configuration.x.bot_protection_enabled = true

    ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = "test-secret-key"
    ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = "1x00000000000000000000AA"

    assert_not CloudflareTurnstileService.new.verify(token: nil)
  ensure
    Rails.configuration.x.bot_protection_enabled = previous
    ENV.delete("CLOUDFLARE_TURNSTILE_SECRET_KEY")
    ENV.delete("CLOUDFLARE_TURNSTILE_SITE_KEY")
  end

  test "rejects blank token when bot_protection_enabled is nil (fail-secure)" do
    previous = Rails.configuration.x.bot_protection_enabled
    Rails.configuration.x.bot_protection_enabled = nil

    ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = "test-secret-key"
    ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = "1x00000000000000000000AA"

    assert_not CloudflareTurnstileService.new.verify(token: nil)
  ensure
    Rails.configuration.x.bot_protection_enabled = previous
    ENV.delete("CLOUDFLARE_TURNSTILE_SECRET_KEY")
    ENV.delete("CLOUDFLARE_TURNSTILE_SITE_KEY")
  end
end
