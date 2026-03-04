module ApplicationHelper
  # Check if user is signed in, safely handling cases where Devise mapping may not be available
  def safe_user_signed_in?
    defined?(current_user) && current_user.present?
  rescue Devise::MissingWarden, ActionController::RoutingError
    false
  end

  # Get current user safely, returning nil if not available
  def safe_current_user
    current_user if safe_user_signed_in?
  rescue Devise::MissingWarden, ActionController::RoutingError
    nil
  end

  def menu_item_destination(menu_item)
    return page_path(menu_item.page) if menu_item.page.present?

    menu_item.url.presence || "#"
  end

  def menu_item_link_options(menu_item, class_name)
    options = { class: class_name }

    if menu_item.open_in_new_tab?
      options[:target] = "_blank"
      options[:rel] = "noopener noreferrer"
    end

    options
  end

  def render_rich_html(content)
    sanitize(
      content,
      tags: RichHtmlSanitizer::ALLOWED_TAGS,
      attributes: RichHtmlSanitizer::ALLOWED_ATTRIBUTES
    )
  end

  def eu_date(value, include_year: true, month: :long, weekday: nil)
    return "" if value.blank?

    weekday_format = case weekday
    when :short
      "%a, "
    when :long
      "%A, "
    else
      ""
    end

    month_format = month == :short ? "%b" : "%B"
    year_format = include_year ? " %Y" : ""

    value.strftime("#{weekday_format}%d #{month_format}#{year_format}")
  end

  def eu_time(value, twelve_hour: false)
    return "" if value.blank?

    value.strftime(twelve_hour ? "%I:%M %p" : "%H:%M")
  end

  def eu_datetime(value, include_year: true, month: :long, weekday: nil, twelve_hour: false, connector: "at")
    return "" if value.blank?

    date_part = eu_date(value, include_year: include_year, month: month, weekday: weekday)
    time_part = eu_time(value, twelve_hour: twelve_hour)

    return "#{date_part} #{time_part}" if connector.blank?

    "#{date_part} #{connector} #{time_part}"
  end

  def eu_date_range(start_value, end_value, month: :short, include_start_year: false, include_end_year: true)
    "#{eu_date(start_value, include_year: include_start_year, month: month)} - #{eu_date(end_value, include_year: include_end_year, month: month)}"
  end
end
