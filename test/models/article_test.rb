require "test_helper"

# == Schema Information
#
# Table name: articles
#
#  id           :bigint           not null, primary key
#  content_html :text
#  title        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_articles_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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

  test "is valid with only content_html" do
    article = Article.new(title: "Article", content_html: "<p>Details</p>", user: users(:admin))

    assert article.valid?
  end

  test "requires content or content_html" do
    article = Article.new(title: "Article", user: users(:admin))

    assert_not article.valid?
    assert_includes article.errors[:content], "can't be blank"
  end

  test "attaches random placeholder main image when none is provided" do
    article = Article.create!(title: "Article", content: "Details", user: users(:admin))

    assert article.main_image.attached?
    assert_includes placeholder_filenames, article.main_image.filename.to_s
  end
end
