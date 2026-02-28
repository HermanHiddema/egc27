class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @recent_articles = Article.order(created_at: :desc).limit(3).includes(:user)
  end
end
