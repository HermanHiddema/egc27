require "test_helper"

class ProductionEnvironmentConfigurationTest < ActiveSupport::TestCase
  test "mailgun delivery method is registered with action mailer" do
    assert ActionMailer::Base.delivery_methods.key?(:mailgun)
  end

  test "production environment uses mailgun delivery method" do
    assert_includes production_config, "config.action_mailer.delivery_method = :mailgun"
    assert_includes production_config, "config.action_mailer.mailgun_settings = {"
    assert_includes production_config, "MAILGUN_API_KEY"
    assert_includes production_config, "MAILGUN_DOMAIN"
  end

  test "production environment connects solid cache to cache database" do
    assert_includes production_config, "config.cache_store = :solid_cache_store"
    assert_match(
      /config\.solid_cache\.connects_to\s*=\s*\{\s*database:\s*\{\s*writing:\s*:cache\s*\}\s*\}/,
      production_config
    )
  end

  private

  def production_config
    @production_config ||= File.read(File.expand_path("../../config/environments/production.rb", __dir__))
  end
end
