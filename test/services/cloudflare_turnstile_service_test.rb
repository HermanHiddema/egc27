require "test_helper"

class CloudflareTurnstileServiceTest < ActiveSupport::TestCase
  test "skips verification and passes when bot protection is disabled" do
    prev_secret_key = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
    prev_site_key = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
    previous = Rails.configuration.x.bot_protection_enabled
    Rails.configuration.x.bot_protection_enabled = false

    ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = "test-secret-key"
    ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = "1x00000000000000000000AA"

    # A blank token would normally fail verification, but it should be allowed
    # through when bot protection is disabled without any network call.
    with_stubbed_net_http_start(->(*_args) { raise Minitest::Assertion, "expected no Turnstile verification network call when bot protection is disabled" }) do
      assert CloudflareTurnstileService.new.verify(token: nil)
    end
  ensure
    Rails.configuration.x.bot_protection_enabled = previous
    prev_secret_key ? ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = prev_secret_key : ENV.delete("CLOUDFLARE_TURNSTILE_SECRET_KEY")
    prev_site_key ? ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = prev_site_key : ENV.delete("CLOUDFLARE_TURNSTILE_SITE_KEY")
  end

  test "rejects blank token when bot protection is enabled and keys are set" do
    prev_secret_key = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
    prev_site_key = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
    previous = Rails.configuration.x.bot_protection_enabled
    Rails.configuration.x.bot_protection_enabled = true

    ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = "test-secret-key"
    ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = "1x00000000000000000000AA"

    assert_not CloudflareTurnstileService.new.verify(token: nil)
  ensure
    Rails.configuration.x.bot_protection_enabled = previous
    prev_secret_key ? ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = prev_secret_key : ENV.delete("CLOUDFLARE_TURNSTILE_SECRET_KEY")
    prev_site_key ? ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = prev_site_key : ENV.delete("CLOUDFLARE_TURNSTILE_SITE_KEY")
  end

  test "rejects blank token when bot_protection_enabled is nil (fail-secure)" do
    prev_secret_key = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
    prev_site_key = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
    previous = Rails.configuration.x.bot_protection_enabled
    Rails.configuration.x.bot_protection_enabled = nil

    ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = "test-secret-key"
    ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = "1x00000000000000000000AA"

    assert_not CloudflareTurnstileService.new.verify(token: nil)
  ensure
    Rails.configuration.x.bot_protection_enabled = previous
    prev_secret_key ? ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = prev_secret_key : ENV.delete("CLOUDFLARE_TURNSTILE_SECRET_KEY")
    prev_site_key ? ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = prev_site_key : ENV.delete("CLOUDFLARE_TURNSTILE_SITE_KEY")
  end

  private

  def with_stubbed_net_http_start(replacement)
    original_start = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start, &replacement)
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, &original_start)
  end
end
