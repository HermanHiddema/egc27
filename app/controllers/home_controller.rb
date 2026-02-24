class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:style_guide, :index]

  def index; end

  def style_guide; end
end
