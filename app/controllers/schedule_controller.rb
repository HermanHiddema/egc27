class ScheduleController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @period_start = Date.new(2027, 7, 24)
    @period_end = Date.new(2027, 8, 7)
    @days = (@period_start..@period_end).to_a
    @selected_date = parse_selected_date(params[:date])
    @start_hour = 9
    @end_hour = 23
    @total_minutes = (@end_hour - @start_hour) * 60.0
    @calendar_events_by_day = calendar_events_in_range(@period_start.beginning_of_day..@period_end.end_of_day)
      .group_by { |calendar_event| calendar_event.starts_at.to_date }
    @selected_day_events = calendar_events_in_range(@selected_date.beginning_of_day..@selected_date.end_of_day)
  end

  private

  def parse_selected_date(value)
    return @period_start unless value.present?

    selected_date = Date.iso8601(value)
    @days.include?(selected_date) ? selected_date : @period_start
  rescue ArgumentError, TypeError
    @period_start
  end

  def calendar_events_in_range(range)
    CalendarEvent
      .where("starts_at <= ? AND ends_at >= ?", range.end, range.begin)
      .includes(:event_group)
      .chronological
  end
end
