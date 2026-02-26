class Page < ApplicationRecord
  validates :title, presence: true
  validates :content, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :assign_slug

  def to_param
    slug
  end

  private

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
end
