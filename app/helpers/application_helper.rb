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
end
