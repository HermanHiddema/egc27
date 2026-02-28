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

  validates :label, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :parent_belongs_to_same_menu
  validate :parent_is_not_self
  validate :destination_is_valid

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
    elsif page_id.blank? && url.blank?
      errors.add(:base, "must have either a page or a URL")
    end
  end
end
