class Menu < ApplicationRecord
  has_many :menu_items, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :menu

  validates :name, presence: true
  validates :location, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
end
