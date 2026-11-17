class Admin::UsersController < ApplicationController
  before_action :require_admin!

  def show
    @user = User.includes(:orders, :participants, :hostel_bookings).find(params[:id])
  end
end
