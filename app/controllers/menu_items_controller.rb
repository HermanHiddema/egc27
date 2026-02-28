class MenuItemsController < ApplicationController
  before_action :set_menu
  before_action :set_menu_item, only: [:show, :edit, :update, :destroy]
  before_action :load_form_collections, only: [:new, :create, :edit, :update]

  def index
    @menu_items = @menu.menu_items.includes(:page, :parent).ordered
  end

  def show
  end

  def new
    @menu_item = @menu.menu_items.new
  end

  def create
    @menu_item = @menu.menu_items.new(menu_item_params)

    if @menu_item.save
      redirect_to [@menu, @menu_item], notice: "Menu item was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @menu_item.update(menu_item_params)
      redirect_to [@menu, @menu_item], notice: "Menu item was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @menu_item.destroy
    redirect_to menu_menu_items_path(@menu), notice: "Menu item was successfully deleted."
  end

  private

  def set_menu
    @menu = Menu.find(params[:menu_id])
  end

  def set_menu_item
    @menu_item = @menu.menu_items.find(params[:id])
  end

  def load_form_collections
    @pages = Page.order(:title)
    @parent_items = @menu.menu_items.ordered
    @parent_items = @parent_items.where.not(id: @menu_item.id) if defined?(@menu_item) && @menu_item.persisted?
  end

  def menu_item_params
    params.require(:menu_item).permit(:label, :page_id, :url, :parent_id, :position, :visible, :open_in_new_tab)
  end
end
