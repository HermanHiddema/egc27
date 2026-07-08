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

  # Render an inline validation error message for a single attribute so the
  # error appears directly on the field instead of only in a summary at the
  # top of the form. Accepts either a form builder or a model instance.
  def field_error(form_or_object, attribute)
    object = form_or_object.respond_to?(:object) ? form_or_object.object : form_or_object
    return unless object.respond_to?(:errors)

    messages = object.errors[attribute]
    return if messages.blank?

    content_tag(
      :p,
      messages.to_sentence,
      class: "mt-1 text-sm text-red-600"
    )
  end

  def menu_item_destination(menu_item)
    if menu_item.page&.slug == "participants"
      return participants_path
    end

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

  def user_registration_menu_link(user = safe_current_user)
    return nil unless user.present?

    participants = user.participants.order(:last_name, :first_name, :id).to_a
    return nil if participants.empty?

    if participants.one?
      { label: "My registration", path: participant_path(participants.first) }
    else
      { label: "My registrations", path: mine_participants_path }
    end
  end

  def main_image_representation(attachment, **transformations)
    return nil unless attachment.attached? && attachment.variable?

    attachment.variant(**transformations)
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

  def country_flag_image(country_code)
    code = country_code.to_s.strip.upcase
    return "" unless code.match?(/\A[A-Z]{2}\z/)

    image_tag(
      "https://flagcdn.com/24x18/#{code.downcase}.png",
      alt: "",
      width: 24,
      height: 18,
      loading: "lazy",
      decoding: "async",
      class: "inline-block rounded-sm align-[-0.1em]"
    )
  end

  def country_with_flag(country_code)
    code = country_code.to_s.strip.upcase
    return code unless code.match?(/\A[A-Z]{2}\z/)

    safe_join([country_flag_image(code), code], " ")
  end

  def egd_player_card_url(pin)
    normalized_pin = pin.to_s.strip
    return nil unless normalized_pin.match?(/\A\d{8}\z/)

    "https://europeangodatabase.eu/EGD/Player_Card.php?&key=#{ERB::Util.url_encode(normalized_pin)}"
  end

  def next_sort_direction(column, current_sort, current_direction)
    return :asc unless current_sort == column

    current_direction == :asc ? :desc : :asc
  end

  def sort_indicator(column, current_sort, current_direction)
    return "" unless current_sort == column

    current_direction == :asc ? "↑" : "↓"
  end

  # Tailwind classes for the coloured status badge shown in the admin
  # participant list. Falls back to a neutral style for unknown statuses.
  def participant_status_badge_class(status)
    case status
    when "Paid" then "bg-green-100 text-green-800"
    when "Confirmed" then "bg-blue-100 text-blue-800"
    when "Pending" then "bg-yellow-100 text-yellow-800"
    else "bg-neutral-100 text-neutral-800"
    end
  end
end
