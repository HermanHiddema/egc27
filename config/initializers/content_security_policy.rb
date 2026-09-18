# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
    policy.object_src      :none

    # Self-hosted JavaScript (importmap, Stimulus, TinyMCE) plus the Cloudflare
    # Turnstile loader. Inline scripts are allowed through a per-request nonce.
    policy.script_src :self, "https://challenges.cloudflare.com"

    # 'unsafe-inline' is still required by TinyMCE and the inline style
    # attributes used in the views; tracked for removal separately.
    policy.style_src :self, :unsafe_inline, "https://cdn.jsdelivr.net"

    # Article/page/sponsor images, Active Storage blobs, TinyMCE icons and the
    # flag images loaded from CDNs by intl-tel-input.
    policy.img_src     :self, :data, :blob, :https
    policy.font_src    :self, :data
    policy.connect_src :self
    # Turnstile renders its challenge inside an iframe.
    policy.frame_src   :self, "https://challenges.cloudflare.com"

    if (report_uri = ENV["CONTENT_SECURITY_POLICY_REPORT_URI"].presence)
      policy.report_uri report_uri
    end
  end

  # Generate per-request nonces so inline scripts (the Turnstile loader and the
  # tags emitted by `javascript_importmap_tags`) do not need 'unsafe-inline'.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Set CONTENT_SECURITY_POLICY_REPORT_ONLY=true to observe violations without
  # enforcing the policy (useful when rolling out changes).
  config.content_security_policy_report_only = ENV["CONTENT_SECURITY_POLICY_REPORT_ONLY"] == "true"
end
