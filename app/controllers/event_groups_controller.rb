class EventGroupsController < ApplicationController
  before_action :require_admin!
  before_action :set_event_group, only: [:edit, :update, :destroy]

  def index
    @event_groups = EventGroup.includes(:calendar_events).order(name: :asc)
  end

  def new
    @event_group = EventGroup.new
  end

  def create
    @event_group = EventGroup.new(event_group_params)

    if @event_group.save
      redirect_to event_groups_url, notice: "Event group was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event_group.update(event_group_params)
      redirect_to event_groups_url, notice: "Event group was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event_group.destroy
    redirect_to event_groups_url, notice: "Event group was successfully deleted."
  end

  private

  def set_event_group
    @event_group = EventGroup.find(params[:id])
  end

  def event_group_params
    params.require(:event_group).permit(:key, :name, :color)
  end
end
