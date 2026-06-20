class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @notices = Notice.active.order(created_at: :desc)
    @recent_articles = Article.with_attached_main_image.with_rich_text_content_and_embeds.order(created_at: :desc).limit(3).includes(:user)
    @recent_participants = Participant.select(:id, :first_name, :last_name, :rank_grade).order(created_at: :desc).limit(10)
  end
end
