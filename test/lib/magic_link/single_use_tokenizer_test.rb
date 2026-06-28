require "test_helper"

class MagicLink::SingleUseTokenizerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "encode stores a digest of the nonce on the user and embeds the nonce" do
    token = MagicLink::SingleUseTokenizer.encode(@user)

    assert @user.reload.magic_link_token.present?
    assert_includes token, MagicLink::SingleUseTokenizer::DELIMITER
    # Raw nonce must never be persisted, only its digest.
    nonce = token.split(MagicLink::SingleUseTokenizer::DELIMITER, 2).last
    refute_equal nonce, @user.magic_link_token
  end

  test "decode returns the resource for a valid, unused token" do
    token = MagicLink::SingleUseTokenizer.encode(@user)

    resource, = MagicLink::SingleUseTokenizer.decode(token, User)
    assert_equal @user, resource
  end

  test "decode rejects a token once the stored digest has been cleared" do
    token = MagicLink::SingleUseTokenizer.encode(@user)
    @user.after_magic_link_authentication

    assert_raises Devise::Passwordless::InvalidTokenError do
      MagicLink::SingleUseTokenizer.decode(token, User)
    end
  end

  test "issuing a new token invalidates the previous one" do
    first_token = MagicLink::SingleUseTokenizer.encode(@user)
    MagicLink::SingleUseTokenizer.encode(@user)

    assert_raises Devise::Passwordless::InvalidTokenError do
      MagicLink::SingleUseTokenizer.decode(first_token, User)
    end
  end

  test "decode raises for a tampered or malformed token" do
    assert_raises Devise::Passwordless::InvalidTokenError do
      MagicLink::SingleUseTokenizer.decode("not-a-valid-token", User)
    end
  end

  test "decode raises when the nonce does not match the stored digest" do
    token = MagicLink::SingleUseTokenizer.encode(@user)
    sgid = token.split(MagicLink::SingleUseTokenizer::DELIMITER, 2).first
    tampered = "#{sgid}#{MagicLink::SingleUseTokenizer::DELIMITER}wrongnonce"

    assert_raises Devise::Passwordless::InvalidTokenError do
      MagicLink::SingleUseTokenizer.decode(tampered, User)
    end
  end
end
