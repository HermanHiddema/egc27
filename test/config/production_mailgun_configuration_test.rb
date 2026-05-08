require "test_helper"

class ProductionMailgunConfigurationTest < ActiveSupport::TestCase
  test "mailgun delivery method is registered with action mailer" do
    assert ActionMailer::Base.delivery_methods.key?(:mailgun)
  end

  test "production environment uses mailgun delivery method" do
    production_config = File.read(File.expand_path("../../config/environments/production.rb", __dir__))

    assert_includes production_config, "config.action_mailer.delivery_method = :mailgun"
    assert_includes production_config, "config.action_mailer.mailgun_settings = {"
    assert_includes production_config, "MAILGUN_API_KEY"
    assert_includes production_config, "MAILGUN_DOMAIN"
  end

  test "production environment configures default url host via DEFAULT_URL_HOST env var with fallback" do
    production_config = File.read(File.expand_path("../../config/environments/production.rb", __dir__))

    assert_includes production_config, "DEFAULT_URL_HOST"
    assert_includes production_config, "egc2027.nl"
    assert_includes production_config, "config.action_mailer.default_url_options"
  end
end
