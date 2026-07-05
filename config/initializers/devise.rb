Devise.setup do |config|
  config.mailer_sender = "no-reply@egc2027.nl"

  require "devise/orm/active_record"

  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]

  config.skip_session_storage = [:http_auth]

  config.stretches = Rails.env.test? ? 1 : 12

  config.reconfirmable = true

  config.expire_all_remember_me_on_sign_out = true

  config.password_length = 6..128

  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  config.timeout_in = 30.minutes

  config.sign_out_via = :delete

  # When using Devise with Hotwire/Turbo, form submissions are handled by Turbo,
  # which only renders responses that redirect (3xx) or signal an error (4xx).
  # Devise defaults to responding with :ok (200) on failures for backwards
  # compatibility, which Turbo ignores silently - so a failed sign in would show
  # no error message. Respond with :unprocessable_entity so Turbo renders the
  # re-rendered form (including the "Invalid email or password." flash), and use
  # :see_other for redirects after successful, non-GET actions.
  config.responder.error_status = :unprocessable_entity
  config.responder.redirect_status = :see_other

  # ==> Configuration for :magic_link_authenticatable

  # Need to use a custom Devise mailer in order to send magic links.
  # If you're already using a custom mailer just have it inherit from
  # Devise::Passwordless::Mailer instead of Devise::Mailer
  config.mailer = "Users::Mailer"

  # Which algorithm to use for tokenizing magic links. See README for descriptions.
  # We use a custom tokenizer that wraps a signed GlobalID with a server-side
  # tracked nonce so that each magic link can only be used once.
  config.passwordless_tokenizer = "::MagicLink::SingleUseTokenizer"

  # Time period after a magic login link is sent out that it will be valid for.
  # config.passwordless_login_within = 20.minutes

  # The secret key used to generate passwordless login tokens. The default value
  # is nil, which means defer to Devise's `secret_key` config value. Changing this
  # key will render invalid all existing passwordless login tokens. You can
  # generate your own secret value with e.g. `rake secret`
  # config.passwordless_secret_key = nil

  # When using the :trackable module and MessageEncryptorTokenizer, set to true to
  # consider magic link tokens generated before the user's current sign in time to
  # be expired. In other words, each time you sign in, all existing magic links
  # will be considered invalid.
  # config.passwordless_expire_old_tokens_on_sign_in = false
end
