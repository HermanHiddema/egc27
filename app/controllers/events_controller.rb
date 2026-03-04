class EventsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :day, :week, :two_weeks, :three_weeks, :list, :show]
  before_action :set_event, only: [:show, :edit, :update, :destroy]

  def index
    @current_view = :month
    @month = parse_month(params[:month])

    month_start = @month.beginning_of_month
    month_end = @month.end_of_month
    @week_anchor_date = month_start.beginning_of_week(:monday)
    @display_start = month_start.beginning_of_week(:monday)
    @display_end = month_end.end_of_week(:monday)

    @calendar_days = (@display_start..@display_end).to_a
    @events_by_day = Event
      .where(starts_at: @display_start.beginning_of_day..@display_end.end_of_day)
      .includes(:user)
      .chronological
      .group_by { |event| event.starts_at.to_date }
  end

  def day
    @current_view = :day
    @date = parse_date(params[:date])
    @events = events_in_range(@date.beginning_of_day..@date.end_of_day)
  end

  def week
    @current_view = :week
    @show_early_hours = ActiveModel::Type::Boolean.new.cast(params[:show_early_hours])
    start_date = parse_date(params[:date]).beginning_of_week(:monday)
    end_date = start_date + 6.days

    @period_start = start_date
    @period_end = end_date
    @days = (@period_start..@period_end).to_a
    @events_by_day = events_in_range(@period_start.beginning_of_day..@period_end.end_of_day)
      .group_by { |event| event.starts_at.to_date }
    @hours = (0..23).to_a
    @positioned_events_by_day = @days.index_with do |day|
      day_start = day.beginning_of_day
      day_end = day.end_of_day

      (@events_by_day[day] || []).filter_map do |event|
        visible_start = [event.starts_at, day_start].max
        visible_end = [event.ends_at, day_end].min
        next if visible_end <= visible_start

        start_minutes = ((visible_start - day_start) / 60.0)
        duration_minutes = ((visible_end - visible_start) / 60.0)

        {
          event: event,
          top_percent: (start_minutes / 1440.0) * 100,
          height_percent: [ (duration_minutes / 1440.0) * 100, (20.0 / 1440.0) * 100 ].max
        }
      end
    end
  end

  def two_weeks
    @current_view = :two_weeks
    start_date = parse_date(params[:date]).beginning_of_week(:monday)
    end_date = start_date + 13.days

    @period_start = start_date
    @period_end = end_date
    @days = (@period_start..@period_end).to_a
    @events_by_day = events_in_range(@period_start.beginning_of_day..@period_end.end_of_day)
      .group_by { |event| event.starts_at.to_date }
  end

  def three_weeks
    @current_view = :three_weeks
    start_date = parse_date(params[:date]).beginning_of_week(:monday)
    end_date = start_date + 20.days

    @period_start = start_date
    @period_end = end_date
    @days = (@period_start..@period_end).to_a
    @events_by_day = events_in_range(@period_start.beginning_of_day..@period_end.end_of_day)
      .group_by { |event| event.starts_at.to_date }
  end

  def list
    @current_view = :list
    @period_start = parse_date(params[:from])
    @period_end = parse_date(params[:to], default: @period_start + 29.days)
    @events = events_in_range(@period_start.beginning_of_day..@period_end.end_of_day)
  end

  def show
  end

  def new
    @event = Event.new(
      starts_at: Time.current.change(min: 0),
      ends_at: 1.hour.from_now.change(min: 0)
    )
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
    month = @event.starts_at.strftime("%Y-%m")
    @event.destroy

    redirect_to calendar_path(month: month), notice: "Event was successfully deleted."
  end

  private

  def set_event
    @event = Event.includes(:user).find(params[:id])
  end

  def event_params
    params.require(:event).permit(:title, :description, :starts_at, :ends_at, :location)
  end

  def events_in_range(range)
    Event
      .where("starts_at <= ? AND ends_at >= ?", range.end, range.begin)
      .includes(:user)
      .chronological
  end

  def parse_date(value, default: Date.current)
    return default unless value.present?

    Date.parse(value)
  rescue ArgumentError
    default
  end

  def parse_month(value)
    return Date.current unless value.present?

    Date.strptime(value, "%Y-%m")
  rescue ArgumentError
    Date.current
  end
end
