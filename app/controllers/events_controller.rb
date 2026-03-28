class EventsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  before_action :require_creator!, only: [:new, :create]
  before_action :require_editor!, only: [:edit, :update]
  before_action :require_admin!, only: [:destroy]
  before_action :set_event, only: [:edit, :update, :destroy]

  def index
    @events = Event.chronological.includes(:user)
  end

  def show
    @event = Event.includes(event_registrations: :participant).find(params[:id])
    @participants = @event.participants.order(:last_name, :first_name)
    @event_registration = EventRegistration.new
  end

  def new
    @event = Event.new
  end

  def create
    @event = current_user.events.build(event_params)

    if @event.save
      redirect_to @event, notice: "Event was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      redirect_to @event, notice: "Event was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to events_path, notice: "Event was successfully deleted."
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:title, :description, :starts_at, :ends_at, :location)
  end
end
