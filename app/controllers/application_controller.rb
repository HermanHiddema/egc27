class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_navigation_menus

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:full_name])
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
