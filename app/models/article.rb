class Article < ApplicationRecord
  ALLOWED_MAIN_IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  PLACEHOLDER_IMAGES_PATH = Rails.root.join("app/assets/images/placeholders").freeze

  belongs_to :user
  has_rich_text :content
  has_one_attached :main_image

  validates :title, presence: true
  validates :content, presence: true
  validate :main_image_must_be_image
  before_validation :attach_random_placeholder_main_image, on: :create

  private

  def attach_random_placeholder_main_image
    return if main_image.attached?

    placeholder_path = placeholder_main_image_paths.sample
    return if placeholder_path.blank?

    content_type = Marcel::MimeType.for(Pathname.new(placeholder_path))

    # Active Storage may consume the IO later in the save lifecycle, so keep
    # a live stream instead of a block-scoped File that gets closed early.
    main_image.attach(
      io: StringIO.new(File.binread(placeholder_path)),
      filename: File.basename(placeholder_path),
      content_type: content_type
    )
  end

  def placeholder_main_image_paths
    Dir.glob(PLACEHOLDER_IMAGES_PATH.join("*"))
      .select { |path| File.file?(path) }
      .select do |path|
        content_type = Marcel::MimeType.for(Pathname.new(path))
        ALLOWED_MAIN_IMAGE_CONTENT_TYPES.include?(content_type)
      end
  end

  def main_image_must_be_image
    return unless main_image.attached?
    return if ALLOWED_MAIN_IMAGE_CONTENT_TYPES.include?(main_image.blob.content_type.to_s)

    errors.add(:main_image, "must be a PNG, JPEG, or WebP image")
  end
end
