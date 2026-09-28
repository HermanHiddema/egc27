class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @notices = Notice.active.order(created_at: :desc, id: :desc).load
    @recent_articles = Article.with_attached_main_image.order(created_at: :desc).limit(3).includes(:user)
    @recent_participants = Participant.select(:id, :first_name, :last_name, :rank).where.not(confirmed_at: nil).order(created_at: :desc, id: :desc).limit(10).load
    @sponsors = Sponsor.with_attached_logo.joins(:logo_attachment).order(:name).load
  end
end
