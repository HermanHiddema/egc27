# == Schema Information
#
# Table name: articles
#
#  id           :bigint           not null, primary key
#  content_html :text
#  slug         :string
#  title        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_articles_on_slug     (slug) UNIQUE
#  index_articles_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Article < ApplicationRecord
  include RichTextSearchable

  ALLOWED_MAIN_IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  PLACEHOLDER_MAIN_IMAGES_GLOB = Rails.root.join("app/assets/images/placeholders/*").freeze
  PLACEHOLDER_MAIN_IMAGE_PATHS = Dir[PLACEHOLDER_MAIN_IMAGES_GLOB.to_s].freeze
  RESERVED_SLUGS = %w[new].freeze

  belongs_to :user
  has_one_attached :main_image

  before_create :attach_placeholder_main_image
  before_validation :set_slug, on: :create

  validates :title, presence: true
  validates :slug, uniqueness: true, allow_nil: true
  validates :content_html, presence: true
  validate :main_image_must_be_image

  def to_param
    slug.presence || id&.to_s
  end

  private

  def set_slug
    return if slug.present? || title.blank?

    base_slug = title.truncate(60, omission: "").parameterize
    return if base_slug.blank?
    base_slug = "article-#{base_slug}" if RESERVED_SLUGS.include?(base_slug) || base_slug.match?(/\A\d+\z/)

    candidate = base_slug
    suffix = 2
    while self.class.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base_slug}-#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end

  def attach_placeholder_main_image
    return if main_image.attached?

    placeholder_path = PLACEHOLDER_MAIN_IMAGE_PATHS.sample
    return if placeholder_path.blank?

    main_image.attach(
      io: StringIO.new(File.binread(placeholder_path)),
      filename: File.basename(placeholder_path),
      content_type: Marcel::MimeType.for(Pathname.new(placeholder_path))
    )
  end

  def main_image_must_be_image
    return unless main_image.attached?
    return if ALLOWED_MAIN_IMAGE_CONTENT_TYPES.include?(main_image.blob.content_type.to_s)

    errors.add(:main_image, "must be a PNG, JPEG, or WebP image")
  end
end
