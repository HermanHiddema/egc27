require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  def svg_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.svg"), "image/svg+xml")
  end

  def placeholder_filenames
    Article::PLACEHOLDER_MAIN_IMAGE_PATHS.map { |path| File.basename(path) }
  end

  test "rejects svg main images" do
    article = Article.new(title: "Article", content: "Details", user: users(:admin))
    article.main_image.attach(svg_upload)

    assert_not article.valid?
    assert_includes article.errors[:main_image], "must be a PNG, JPEG, or WebP image"
  end

  test "attaches random placeholder main image when none is provided" do
    article = Article.create!(title: "Article", content: "Details", user: users(:admin))

    assert article.main_image.attached?
    assert_includes placeholder_filenames, article.main_image.filename.to_s
  end
end
