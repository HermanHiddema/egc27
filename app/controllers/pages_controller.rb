class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[about schedule registration venue contact]

  def about; end

  def schedule; end

  def registration; end

  def venue; end

  def contact; end
end
