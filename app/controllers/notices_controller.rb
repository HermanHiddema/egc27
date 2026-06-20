class NoticesController < ApplicationController
  before_action :require_creator!, only: [:new, :create]
  before_action :require_editor!, only: [:edit, :update]
  before_action :require_admin!, only: [:destroy, :deactivate, :reactivate]
  before_action :set_notice, only: [:edit, :update, :destroy, :deactivate, :reactivate]

  def index
    @notices = Notice.order(created_at: :desc)
  end

  def new
    @notice = Notice.new
  end

  def create
    @notice = Notice.new(notice_params)

    if @notice.save
      redirect_to notices_path, notice: "Notice was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @notice.update(notice_params)
      redirect_to notices_path, notice: "Notice was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @notice.destroy
    redirect_to notices_path, notice: "Notice was successfully deleted."
  end

  def deactivate
    @notice.deactivate
    undo_link = view_context.link_to('Undo', reactivate_notice_path(@notice), method: :patch, data: { turbo_method: :patch }, class: "underline font-semibold text-green-700 hover:text-green-800")
    redirect_to root_path, notice: "Notice has been deactivated. #{undo_link} this action.".html_safe
  end

  def reactivate
    @notice.reactivate
    redirect_to root_path, notice: "Notice has been reactivated."
  end

  private

  def set_notice
    @notice = Notice.find(params[:id])
  end

  def notice_params
    params.require(:notice).permit(:title, :body, :active)
  end
end
