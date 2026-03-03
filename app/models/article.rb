class Article < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :content, presence: true

  # Sanitize HTML content before saving to prevent XSS attacks
  before_save :sanitize_content

  private

  def sanitize_content
    self.content = RichHtmlSanitizer.sanitize_html(content)
  end
end
