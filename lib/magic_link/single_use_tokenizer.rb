require "digest"
require "securerandom"
require "active_support/security_utils"

module MagicLink
  # Tokenizer that makes magic links single-use.
  #
  # It wraps a signed GlobalID (so the resource and expiry are tamper-proof and
  # stateless) with a random, server-side tracked nonce. The SHA-256 digest of
  # the nonce is stored on the user in +magic_link_token+ when the link is
  # generated, and cleared once the link is used (see
  # User#after_magic_link_authentication). A link whose nonce no longer matches
  # the stored digest is rejected, so each link works exactly once. Generating a
  # new link also invalidates any previously issued link for that user.
  class SingleUseTokenizer
    # A character that never appears in a signed GlobalID (Base64 + "--" + hex)
    # nor in the urlsafe Base64 nonce, so splitting is unambiguous.
    DELIMITER = "~".freeze

    def self.encode(resource, expires_in: nil, expires_at: nil)
      nonce = SecureRandom.urlsafe_base64(32)
      resource.update_column(:magic_link_token, digest(nonce))

      sgid = if expires_at
        resource.to_sgid(expires_at: expires_at, for: "login").to_s
      else
        resource.to_sgid(expires_in: expires_in || resource.class.passwordless_login_within, for: "login").to_s
      end

      "#{sgid}#{DELIMITER}#{nonce}"
    end

    def self.decode(token, resource_class)
      sgid, nonce = token.to_s.split(DELIMITER, 2)
      raise Devise::Passwordless::InvalidTokenError if sgid.blank? || nonce.blank?

      resource = GlobalID::Locator.locate_signed(sgid, for: "login")
      raise Devise::Passwordless::ExpiredTokenError unless resource
      raise Devise::Passwordless::InvalidTokenError if resource.class != resource_class

      stored = resource.magic_link_token
      raise Devise::Passwordless::InvalidTokenError if stored.blank?
      expected = digest(nonce)
      raise Devise::Passwordless::InvalidTokenError unless stored.bytesize == expected.bytesize
      raise Devise::Passwordless::InvalidTokenError unless ActiveSupport::SecurityUtils.secure_compare(stored, expected)

      [resource, {}]
    end

    def self.digest(nonce)
      Digest::SHA256.hexdigest(nonce)
    end
  end
end
