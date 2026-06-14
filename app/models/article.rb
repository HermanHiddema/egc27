class Article < ApplicationRecord
  ALLOWED_MAIN_IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  PLACEHOLDER_MAIN_IMAGES_GLOB = Rails.root.join("app/assets/images/placeholders/*").freeze
  PLACEHOLDER_MAIN_IMAGE_PATHS = Dir[PLACEHOLDER_MAIN_IMAGES_GLOB.to_s].freeze

  belongs_to :user
  has_rich_text :content
  has_one_attached :main_image

  before_validation :attach_placeholder_main_image, on: :create

  validates :title, presence: true
  validates :content, presence: true
  validate :main_image_must_be_image

  private

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
