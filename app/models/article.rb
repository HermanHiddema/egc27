class Article < ApplicationRecord
  belongs_to :user
  has_rich_text :content
  has_one_attached :main_image

  validates :title, presence: true
  validates :content, presence: true
  validate :main_image_must_be_image

  private

  def main_image_must_be_image
    return unless main_image.attached? && !main_image.blob.content_type.start_with?("image/")

    errors.add(:main_image, "must be an image")
  end
end
