require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  def png_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.png"), "image/png")
  end

  def svg_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/main-image.svg"), "image/svg+xml")
  end

  test "rejects svg main images" do
    article = Article.new(title: "Article", content: "Details", user: users(:admin))
    article.main_image.attach(svg_upload)

    assert_not article.valid?
    assert_includes article.errors[:main_image], "must be a PNG, JPEG, or WebP image"
  end

  test "attaches a random placeholder main image when none is provided" do
    article = Article.create!(title: "Article", content: "Details", user: users(:admin))
    placeholder_filenames = Dir.glob(Rails.root.join("app/assets/images/placeholders/*"))
      .map { |path| File.basename(path) }
      .select { |name| name.match?(/\.(png|jpe?g|webp)\z/i) }

    assert article.main_image.attached?
    assert_includes Article::ALLOWED_MAIN_IMAGE_CONTENT_TYPES, article.main_image.blob.content_type
    assert_includes placeholder_filenames, article.main_image.filename.to_s
  end

  test "does not replace an explicitly uploaded main image" do
    article = Article.create!(title: "Article", content: "Details", user: users(:admin), main_image: png_upload)

    assert article.main_image.attached?
    assert_equal "main-image.png", article.main_image.filename.to_s
  end
end
