class SponsorsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @sponsors = Sponsor.with_attached_logo.order(:name)
  end
end
