# == Schema Information
#
# Table name: notices
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  body       :text
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Notice < ApplicationRecord
  validates :title, presence: true

  scope :active, -> { where(active: true) }

  def deactivate
    update(active: false)
  end

  def reactivate
    update(active: true)
  end
end
