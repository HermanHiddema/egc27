class Admin::ParticipantTicketsController < ApplicationController
  before_action :require_admin!

  def show
    @ticket = ParticipantTicket.includes(:participant, product: { order: :payments }).find(params[:id])
  end
end
