Mollie::Client.configure do |config|
  config.api_key = Rails.application.credentials.mollie_api_key.presence ||
                   ENV.fetch("MOLLIE_API_KEY", nil).presence
end

if Rails.env.production? && Mollie::Client.instance.api_key.blank?
  Rails.logger.warn "[Mollie] No API key configured. Set MOLLIE_API_KEY or add mollie_api_key to credentials."
end
