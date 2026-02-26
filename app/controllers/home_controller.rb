class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:style_guide, :index, :debug]

  def index
    @recent_articles = Article.order(created_at: :desc).limit(3).includes(:user)
  end

  def style_guide; end

  def debug
    @user_count = User.count
    @test_user = User.find_by(email: "test@example.com")
    @user_signed_in = user_signed_in?
    @current_user = current_user if user_signed_in?
  end
end
