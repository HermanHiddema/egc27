class Admin::ParticipantTicketsController < ApplicationController
  before_action :require_admin!

  def show
    @ticket = ParticipantTicket.includes(:participant, product: { order: :payments }).find(params[:id])
    @payment = @ticket.product&.order&.payments&.select(&:paid?)&.max_by { |payment| [payment.created_at, payment.id] }
    @pricing = CongressPassPricing.new(attendance_option: @ticket.participant.attendance_option,
                                       age_group: @ticket.participant.age_group,
                                       payment_date: @payment&.payment_date || Date.current)
  end
end
