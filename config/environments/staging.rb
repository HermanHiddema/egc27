# The staging environment is identical to production, except that email is
# delivered through SMTP instead of Mailgun. All other settings are inherited
# from config/environments/production.rb so that staging mirrors production as
# closely as possible.
require_relative "production"

Rails.application.configure do
  # Deliver email through SMTP. Configure the server via smtp/* credentials
  # (bin/rails credentials:edit) or the matching SMTP_* environment variables.
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: Rails.application.credentials.dig(:smtp, :address) || ENV["SMTP_ADDRESS"],
    port: Integer(Rails.application.credentials.dig(:smtp, :port) || ENV["SMTP_PORT"], exception: false) || 587,
    domain: Rails.application.credentials.dig(:smtp, :domain) || ENV["SMTP_DOMAIN"],
    user_name: Rails.application.credentials.dig(:smtp, :user_name) || ENV["SMTP_USER_NAME"],
    password: Rails.application.credentials.dig(:smtp, :password) || ENV["SMTP_PASSWORD"],
    authentication: (Rails.application.credentials.dig(:smtp, :authentication) || ENV["SMTP_AUTHENTICATION"].presence || "plain").to_sym,
    enable_starttls_auto: true
  }.compact
end
