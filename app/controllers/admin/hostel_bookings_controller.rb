class Admin::HostelBookingsController < ApplicationController
  before_action :require_admin!

  def index
    @hostel_bookings = HostelBooking.includes(:user).order(created_at: :desc, id: :desc)
  end
end
