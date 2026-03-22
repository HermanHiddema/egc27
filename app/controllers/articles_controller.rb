class ArticlesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  before_action :set_article, only: [:show, :edit, :update, :destroy]
  before_action :require_editor!, only: [:new, :create, :edit, :update]
  before_action :require_admin!, only: [:destroy]

  def index
    @articles = Article.with_rich_text_content_and_embeds.order(created_at: :desc).includes(:user)
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
    if @article.update(article_params)
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
    @article = Article.with_rich_text_content_and_embeds.find(params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :content)
  end
end
