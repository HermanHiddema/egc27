# == Schema Information
#
# Table name: event_groups
#
#  id         :bigint           not null, primary key
#  color      :string
#  key        :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_event_groups_on_key  (key) UNIQUE
#
class EventGroup < ApplicationRecord
  has_many :calendar_events, dependent: :nullify

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true

  scope :ordered_by_name, -> { order(name: :asc) }
end
