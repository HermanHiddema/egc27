Mollie::Client.configure do |config|
  config.api_key = Rails.application.credentials.mollie_api_key ||
                   ENV.fetch("MOLLIE_API_KEY", nil)
end
