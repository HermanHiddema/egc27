# == Schema Information
#
# Table name: newsletters
#
#  id           :bigint           not null, primary key
#  content_html :text             not null
#  sent_at      :datetime
#  subject      :string           not null
#  title        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_newsletters_on_sent_at  (sent_at)
#  index_newsletters_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Newsletter < ApplicationRecord
  belongs_to :user
  has_many :newsletter_deliveries, dependent: :delete_all

  scope :sent, -> { where.not(sent_at: nil) }
  scope :drafts, -> { where(sent_at: nil) }

  validates :title, :subject, :content_html, presence: true

  def sent?
    sent_at.present?
  end
end
