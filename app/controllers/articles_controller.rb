class ArticlesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  before_action :require_creator!, only: [:new, :create]
  before_action :require_editor!, only: [:edit, :update]
  before_action :require_admin!, only: [:destroy]
  before_action :set_article, only: [:show, :edit, :update, :destroy]

  def index
    @articles = Article.with_attached_main_image.with_rich_text_content_and_embeds.order(created_at: :desc).includes(:user)
  end

  def show
  end

  def new
    @article = Article.new
  end

  def create
    @article = current_user.articles.build(article_params)

    if @article.save
      redirect_to @article, notice: "Article was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if article_params[:remove_main_image] == "1" && @article.main_image.attached?
      @article.main_image.purge
    end

    if @article.update(article_params.except(:remove_main_image))
      redirect_to @article, notice: "Article was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @article.destroy
    redirect_to articles_path, notice: "Article was successfully deleted."
  end

  private

  def set_article
    @article = Article.with_attached_main_image.with_rich_text_content_and_embeds.find(params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :content, :content_html, :main_image, :remove_main_image)
  end
end
