module Admin
  class MenusController < BaseController
    def index
      @menus = Menu
        .left_joins(:menu_items)
        .select("menus.*, COUNT(menu_items.id) AS menu_items_count")
        .group("menus.id")
        .order(:location, :name)
    end
  end
end
