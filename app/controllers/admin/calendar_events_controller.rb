module Admin
  class CalendarEventsController < BaseController
    before_action :set_calendar_event, only: [:edit, :update, :destroy]

    def index
      @calendar_events = CalendarEvent.includes(:user, :event_group).order(starts_at: :desc)
    end

    def new
      @calendar_event = CalendarEvent.new
      @users = User.where(role: [:editor, :admin]).ordered_by_name
      @event_groups = EventGroup.ordered_by_name
    end

    def create
      @calendar_event = CalendarEvent.new(calendar_event_params)

      if @calendar_event.save
        redirect_to admin_calendar_events_url, notice: "Event was successfully created."
      else
        @users = User.where(role: [:editor, :admin]).ordered_by_name
        @event_groups = EventGroup.ordered_by_name
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @users = User.where(role: [:editor, :admin]).ordered_by_name
      @event_groups = EventGroup.ordered_by_name
    end

    def update
      if @calendar_event.update(calendar_event_params)
        redirect_to admin_calendar_events_url, notice: "Event was successfully updated."
      else
        @users = User.where(role: [:editor, :admin]).ordered_by_name
        @event_groups = EventGroup.ordered_by_name
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @calendar_event.destroy
      redirect_to admin_calendar_events_url, notice: "Event was successfully deleted."
    end

    private

    def set_calendar_event
      @calendar_event = CalendarEvent.find(params[:id])
    end

    def calendar_event_params
      params.require(:calendar_event).permit(:title, :description, :starts_at, :ends_at, :location, :color, :user_id, :event_group_id)
    end
  end
end
