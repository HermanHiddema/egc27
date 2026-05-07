require "test_helper"

class ProductionMailgunConfigurationTest < ActiveSupport::TestCase
  test "mailgun delivery method is registered with action mailer" do
    assert ActionMailer::Base.delivery_methods.key?(:mailgun)
  end

  def test_production_environment_uses_mailgun_delivery_method
    production_config = File.read(File.expand_path("../../config/environments/production.rb", __dir__))

    assert_includes production_config, "config.action_mailer.delivery_method = :mailgun"
    assert_includes production_config, "config.action_mailer.mailgun_settings = {"
    assert_includes production_config, "MAILGUN_API_KEY"
    assert_includes production_config, "MAILGUN_DOMAIN"
  end
end
