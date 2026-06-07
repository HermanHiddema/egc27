class Sponsor < ApplicationRecord
  has_one_attached :logo

  validates :name, presence: true
  validate :website_url_must_be_valid
  validate :social_media_links_must_be_valid

  private

  def website_url_must_be_valid
    return if website.blank? || valid_http_url?(website)

    errors.add(:website, "must be a valid HTTP(S) URL")
  end

  def social_media_links_must_be_valid
    return if social_media_links.blank?

    unless social_media_links.is_a?(Hash)
      errors.add(:social_media_links, "must be a key/value object")
      return
    end

    social_media_links.each_value do |url|
      next if url.blank?
      next if valid_http_url?(url)

      errors.add(:social_media_links, "must only contain valid HTTP(S) URLs")
      break
    end
  end

  def valid_http_url?(value)
    uri = URI.parse(value)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end
end
