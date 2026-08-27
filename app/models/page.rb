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
class Page < ApplicationRecord
  include RichTextSearchable

  ALLOWED_MAIN_IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze

  # Public pages are readable by everyone, authenticated pages only by signed-in users.
  enum :access_level, { public: "public", authenticated: "authenticated" }, prefix: :access_level

  has_many :menu_items, dependent: :nullify, inverse_of: :page
  has_rich_text :content
  has_one_attached :main_image

  validates :title, presence: true
  validate :content_must_be_present
  validates :slug, presence: true, uniqueness: true
  validate :main_image_must_be_image

  before_validation :assign_slug

  scope :readable_by, ->(user) { user.present? ? all : where(access_level: :public) }

  def readable_by?(user)
    access_level_public? || user.present?
  end

  def to_param
    slug
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
