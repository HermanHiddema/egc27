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
end
