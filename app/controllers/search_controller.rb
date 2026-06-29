class SearchController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @query = params[:q].to_s.strip

    if @query.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

      @pages = Page.with_attached_main_image
        .left_joins(:rich_text_content)
        .where("pages.title ILIKE :q OR action_text_rich_texts.body ILIKE :q", q: pattern)
        .distinct
        .order(:title)

      @articles = Article.with_attached_main_image
        .left_joins(:rich_text_content)
        .where("articles.title ILIKE :q OR action_text_rich_texts.body ILIKE :q", q: pattern)
        .distinct
        .order(created_at: :desc)
        .includes(:user)
    else
      @pages = Page.none
      @articles = Article.none
    end
  end
end
