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
