class ScheduleController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @period_start = Date.new(2027, 7, 24)
    @period_end = Date.new(2027, 8, 8)
    @days = (@period_start..@period_end).to_a
    @start_hour = 9
    @end_hour = 23
    @total_minutes = (@end_hour - @start_hour) * 60.0
    @calendar_events_by_day = calendar_events_in_range(@period_start.beginning_of_day..@period_end.end_of_day)
      .group_by { |calendar_event| calendar_event.starts_at.to_date }
  end

  private

  def calendar_events_in_range(range)
    CalendarEvent
      .where("starts_at <= ? AND ends_at >= ?", range.end, range.begin)
      .includes(:event_group)
      .chronological
  end
end
