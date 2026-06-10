class Article < ApplicationRecord
  ALLOWED_MAIN_IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze

  belongs_to :user
  has_rich_text :content
  has_one_attached :main_image

  validates :title, presence: true
  validates :content, presence: true
  validate :main_image_must_be_image

  private

  def main_image_must_be_image
    return unless main_image.attached?
    return if ALLOWED_MAIN_IMAGE_CONTENT_TYPES.include?(main_image.blob.content_type.to_s)

    errors.add(:main_image, "must be a PNG, JPEG, or WebP image")
  end
end
