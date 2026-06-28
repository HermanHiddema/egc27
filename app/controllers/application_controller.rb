class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Server-to-server endpoints (e.g. payment provider webhooks) opt out via #skip_browser_version_guard?.
  allow_browser versions: :modern, unless: :skip_browser_version_guard?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_navigation_menus

  protected

  # After signing in, send users to their own registrations, which is the most
  # useful landing spot. Applies to every sign-in path (password and magic link).
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || mine_participants_path
  end

  # Browser version enforcement applies to interactive (browser) requests only.
  # Controllers serving machine-to-machine endpoints override this to opt out.
  def skip_browser_version_guard?
    false
  end

  def require_creator!
    redirect_to root_path, alert: "You are not authorized to perform this action." unless current_user&.can_create?
  end

  def require_editor!
    redirect_to root_path, alert: "You are not authorized to perform this action." unless current_user&.can_edit?
  end

  def require_admin!
    redirect_to root_path, alert: "You are not authorized to perform this action." unless current_user&.can_delete?
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: [:full_name])
  end

  def set_navigation_menus
    @header_menu = Menu.active.find_by(location: "header")

    if @header_menu.present?
      @header_menu_root_items = @header_menu.menu_items
        .visible
        .roots
        .ordered
        .includes(:page, children: [:page, { children: :page }])
        .to_a
    end

    @footer_menu = Menu.active.find_by(location: "footer")

    if @footer_menu.present?
      @footer_menu_root_items = @footer_menu.menu_items
        .visible
        .roots
        .ordered
        .includes(:page)
        .to_a
    end
  end
end
