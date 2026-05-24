module Admin
  class MenusController < BaseController
    def index
      @menus = Menu.order(:location, :name)
    end
  end
end
