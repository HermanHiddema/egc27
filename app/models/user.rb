class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable

  has_many :articles, dependent: :destroy

  def display_name
    full_name.presence || email
  end
end
