class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  before_action :set_page, only: [:show, :edit, :update, :destroy]

  def index
    @pages = Page.order(:title)
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
    if @page.update(page_params)
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
    @page = Page.find_by!(slug: params[:slug])
  end

  def page_params
    params.require(:page).permit(:title, :content, :slug)
  end
end