require "test_helper"

class PageTest < ActiveSupport::TestCase
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
end
