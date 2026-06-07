require "test_helper"

class SponsorTest < ActiveSupport::TestCase
  test "requires name" do
    sponsor = Sponsor.new(website: "https://example.org")

    assert_not sponsor.valid?
    assert_includes sponsor.errors[:name], "can't be blank"
  end

  test "accepts valid website and social media links" do
    sponsor = Sponsor.new(
      name: "Open Source Org",
      website: "https://example.org",
      social_media_links: {
        x: "https://x.com/example",
        linkedin: "https://www.linkedin.com/company/example"
      },
      description: "Community sponsor."
    )

    assert sponsor.valid?
  end

  test "rejects invalid website url" do
    sponsor = Sponsor.new(name: "Bad Website", website: "javascript:alert(1)")

    assert_not sponsor.valid?
    assert_includes sponsor.errors[:website], "must be a valid HTTP(S) URL"
  end

  test "rejects invalid social media urls" do
    sponsor = Sponsor.new(
      name: "Bad Social",
      social_media_links: { x: "not-a-url" }
    )

    assert_not sponsor.valid?
    assert_includes sponsor.errors[:social_media_links], "must only contain valid HTTP(S) URLs"
  end

  test "defines logo attachment" do
    sponsor = Sponsor.new(name: "Logo Sponsor")

    assert_respond_to sponsor, :logo
  end
end
