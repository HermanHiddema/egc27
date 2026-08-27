class ApplicationController < ActionController::Base
  include PaperTrail::Rails::Controller

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_navigation_menus
  before_action :set_paper_trail_whodunnit

  protected

  # After signing in, send users to their own registrations by default, which is the most
  # useful landing spot. Still honors a stored return-to location when present (e.g. when
  # authentication was required mid-flow).
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || mine_participants_path
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
        .select { |item| item.visible_to?(current_user) }
    end

    @footer_menu = Menu.active.find_by(location: "footer")

    if @footer_menu.present?
      @footer_menu_root_items = @footer_menu.menu_items
        .visible
        .roots
        .ordered
        .includes(:page)
        .select { |item| item.visible_to?(current_user) }
    end
  end
end
