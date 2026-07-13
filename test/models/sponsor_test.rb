require "test_helper"

# == Schema Information
#
# Table name: sponsors
#
#  id                 :bigint           not null, primary key
#  description        :text
#  name               :string           not null
#  social_media_links :jsonb            not null
#  website            :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
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

  test "rejects non-hash social media links payload" do
    sponsor = Sponsor.new(
      name: "Invalid Social Payload",
      social_media_links: "not-a-hash"
    )

    assert_not sponsor.valid?
    assert_includes sponsor.errors[:social_media_links], "must be a key/value object"
  end

  test "defines logo attachment" do
    sponsor = Sponsor.new(name: "Logo Sponsor")

    assert_respond_to sponsor, :logo
  end

  test "accepts svg logo" do
    sponsor = Sponsor.new(name: "SVG Sponsor")
    sponsor.logo.attach(
      Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.svg"), "image/svg+xml")
    )

    assert sponsor.valid?
  end

  test "accepts png logo" do
    sponsor = Sponsor.new(name: "PNG Sponsor")
    sponsor.logo.attach(
      Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.png"), "image/png")
    )

    assert sponsor.valid?
  end

  test "rejects unsupported logo content type" do
    sponsor = Sponsor.new(name: "Bad Logo")
    sponsor.logo.attach(
      io: StringIO.new("not an image"),
      filename: "logo.txt",
      content_type: "text/plain"
    )

    assert_not sponsor.valid?
    assert_includes sponsor.errors[:logo], "must be a PNG, JPEG, WebP, or SVG image"
  end
end
