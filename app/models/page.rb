class Page < ApplicationRecord
  include PgSearch::Model

  ALLOWED_MAIN_IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze

  has_many :menu_items, dependent: :nullify, inverse_of: :page
  has_rich_text :content
  has_one_attached :main_image

  multisearchable against: [:title, :searchable_content]

  validates :title, presence: true
  validate :content_must_be_present
  validates :slug, presence: true, uniqueness: true
  validate :main_image_must_be_image

  before_validation :assign_slug

  def to_param
    slug
  end

  # Plain-text content used for full-text indexing. Prefers TinyMCE-authored
  # HTML and falls back to the legacy Action Text body, with markup stripped.
  def searchable_content
    ActionController::Base.helpers.strip_tags(content_html.presence || content&.body&.to_s)
  end

  private

  def content_must_be_present
    return if content.present? || content_html.present?

    errors.add(:content, "can't be blank")
  end

  def assign_slug
    base_slug = if slug.present?
      slug.to_s.parameterize
    else
      title.to_s.parameterize
    end

    return if base_slug.blank?

    self.slug = unique_slug_for(base_slug)
  end

  def unique_slug_for(base_slug)
    candidate = base_slug
    suffix = 2

    while Page.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base_slug}-#{suffix}"
      suffix += 1
    end

    candidate
  end

  def main_image_must_be_image
    return unless main_image.attached?
    return if ALLOWED_MAIN_IMAGE_CONTENT_TYPES.include?(main_image.blob.content_type.to_s)

    errors.add(:main_image, "must be a PNG, JPEG, or WebP image")
  end
end
