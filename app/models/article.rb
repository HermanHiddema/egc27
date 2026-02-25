class Article < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :content, presence: true

  # Sanitize HTML content before saving to prevent XSS attacks
  before_save :sanitize_content

  private

  def sanitize_content
    # Allow only safe HTML tags and attributes
    self.content = ActionController::Base.helpers.sanitize(
      content,
      tags: %w[p br strong em u h1 h2 h3 h4 h5 h6 ul ol li a blockquote code pre],
      attributes: %w[href title]
    )
  end
end
