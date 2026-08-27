class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  before_action :require_creator!, only: [:new, :create]
  before_action :require_editor!, only: [:edit, :update]
  before_action :require_admin!, only: [:destroy]
  before_action :set_page, only: [:show, :edit, :update, :destroy]
  before_action :require_page_access!, only: [:show]

  def index
    @pages = Page.readable_by(current_user).with_attached_main_image.order(:title)
  end

  def show
  end

  def new
    @page = Page.new
  end

  def create
    @page = Page.new(page_params)

    if @page.save
      redirect_to @page, notice: "Page was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if page_params[:remove_main_image] == "1" && @page.main_image.attached?
      @page.main_image.purge
    end

    if @page.update(page_params.except(:remove_main_image))
      redirect_to @page, notice: "Page was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @page.destroy
    redirect_to pages_path, notice: "Page was successfully deleted."
  end

  private

  def set_page
    @page = Page.with_attached_main_image.with_rich_text_content_and_embeds.find_by!(slug: params[:slug])
  end

  def require_page_access!
    return if @page.readable_by?(current_user)

    authenticate_user!
  end

  def page_params
    params.require(:page).permit(:title, :content, :content_html, :slug, :access_level, :main_image, :remove_main_image)
  end
end
