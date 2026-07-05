# == Schema Information
#
# Table name: menu_items
#
#  id              :bigint           not null, primary key
#  label           :string           not null
#  open_in_new_tab :boolean          default(FALSE), not null
#  position        :integer          default(0), not null
#  url             :string
#  visible         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  menu_id         :bigint           not null
#  page_id         :bigint
#  parent_id       :bigint
#
# Indexes
#
#  index_menu_items_on_menu_id                             (menu_id)
#  index_menu_items_on_menu_id_and_parent_id_and_position  (menu_id,parent_id,position)
#  index_menu_items_on_page_id                             (page_id)
#  index_menu_items_on_parent_id                           (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (menu_id => menus.id)
#  fk_rails_...  (page_id => pages.id)
#  fk_rails_...  (parent_id => menu_items.id)
#
class MenuItem < ApplicationRecord
  belongs_to :menu
  belongs_to :parent, class_name: "MenuItem", optional: true, inverse_of: :children
  belongs_to :page, optional: true

  has_many :children,
    -> { order(:position, :id) },
    class_name: "MenuItem",
    foreign_key: :parent_id,
    dependent: :destroy,
    inverse_of: :parent

  normalizes :url, with: ->(url) { url.strip }

  validates :label, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :parent_belongs_to_same_menu
  validate :parent_is_not_self
  validate :destination_is_valid
  validate :url_is_external_or_local_path

  scope :visible, -> { where(visible: true) }
  scope :roots, -> { where(parent_id: nil) }
  scope :ordered, -> { order(:position, :id) }

  private

  def parent_belongs_to_same_menu
    return if parent.blank? || parent.menu_id == menu_id

    errors.add(:parent_id, "must belong to the same menu")
  end

  def parent_is_not_self
    return if parent_id.blank? || parent_id != id

    errors.add(:parent_id, "cannot reference itself")
  end

  def destination_is_valid
    if page_id.present? && url.present?
      errors.add(:base, "choose either a page or a URL, not both")
    end
  end

  def url_is_external_or_local_path
    return if url.blank?
    return if url.start_with?("#")

    if url.start_with?("/") && !url.start_with?("//")
      URI.parse(url)
      return
    end

    uri = URI.parse(url)
    return if uri.host.present? && uri.scheme.present? && %w[http https].include?(uri.scheme.downcase)

    errors.add(:url, "must be a full URL or a local path starting with /")
  rescue URI::InvalidURIError
    errors.add(:url, "must be a full URL or a local path starting with /")
  end
end
