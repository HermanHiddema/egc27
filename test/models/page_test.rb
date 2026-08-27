require "test_helper"

# == Schema Information
#
# Table name: pages
#
#  id           :bigint           not null, primary key
#  access_level :string           default("public"), not null
#  content_html :text
#  slug         :string           not null
#  title        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_pages_on_slug  (slug) UNIQUE
#
class PageTest < ActiveSupport::TestCase
  def svg_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.svg"), "image/svg+xml")
  end

  test "generates slug from title when slug is blank" do
    page = Page.create!(title: "Venue Information", content: "Details")

    assert_equal "venue-information", page.slug
  end

  test "adds numeric suffix when slug already exists" do
    Page.create!(title: "Schedule", content: "A")
    second_page = Page.create!(title: "Schedule", content: "B")

    assert_equal "schedule-2", second_page.slug
  end

  test "parameterizes manually entered slug" do
    page = Page.create!(title: "Custom", content: "Text", slug: "My Custom Slug")

    assert_equal "my-custom-slug", page.slug
  end

  test "rejects svg main images" do
    page = Page.new(title: "Venue Information", content: "Details")
    page.main_image.attach(svg_upload)

    assert_not page.valid?
    assert_includes page.errors[:main_image], "must be a PNG, JPEG, or WebP image"
  end

  test "is valid with only content_html" do
    page = Page.new(title: "Venue Information", content_html: "<p>Details</p>")

    assert page.valid?
  end

  test "requires content or content_html" do
    page = Page.new(title: "Venue Information")

    assert_not page.valid?
    assert_includes page.errors[:content], "can't be blank"
  end

  test "pages are public by default" do
    page = Page.create!(title: "Venue Information", content: "Details")

    assert page.access_level_public?
    assert page.readable_by?(nil)
  end

  test "authenticated pages are only readable by signed-in users" do
    page = pages(:members_only)

    assert page.access_level_authenticated?
    assert_not page.readable_by?(nil)
    assert page.readable_by?(users(:one))
  end

  test "readable_by scope hides authenticated pages from visitors" do
    assert_not_includes Page.readable_by(nil), pages(:members_only)
    assert_includes Page.readable_by(nil), pages(:one)
    assert_includes Page.readable_by(users(:one)), pages(:members_only)
  end
end
