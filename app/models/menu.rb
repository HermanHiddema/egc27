# == Schema Information
#
# Table name: menus
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  location   :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_menus_on_location  (location) UNIQUE
#
class Menu < ApplicationRecord
  has_many :menu_items, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :menu

  validates :name, presence: true
  validates :location, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
end
