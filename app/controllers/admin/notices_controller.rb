module Admin
  class NoticesController < BaseController
    before_action :set_notice, only: [:edit, :update, :destroy]

    def index
      @notices = Notice.order(created_at: :desc)
    end

    def new
      @notice = Notice.new
    end

    def create
      @notice = Notice.new(notice_params)

      if @notice.save
        redirect_to admin_notices_path, notice: "Notice was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @notice.update(notice_params)
        redirect_to admin_notices_path, notice: "Notice was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @notice.destroy
      redirect_to admin_notices_path, notice: "Notice was successfully deleted."
    end

    private

    def set_notice
      @notice = Notice.find(params[:id])
    end

    def notice_params
      params.require(:notice).permit(:title, :body, :active)
    end
  end
end
