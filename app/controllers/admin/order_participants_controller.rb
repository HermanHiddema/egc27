class Admin::OrderParticipantsController < ApplicationController
  include ParticipantRegistrationParameters
  before_action :require_admin!
  before_action :set_order

  def new
    @participant = @order.user.participants.build(email: @order.user.email)
    render "participants/new"
  end

  def create
    @order.with_lock do
      raise ActiveRecord::RecordNotSaved, "Only draft Orders can be edited." unless @order.editable?
      if params.permit(:registration_owner_id)[:registration_owner_id].to_s != @order.user_id.to_s
        raise ActiveRecord::RecordNotSaved, "The Order owner changed. Review the basket before registering a participant."
      end

      @participant = @order.user.participants.build(participant_params)
      @participant.email = @order.user.email
      @participant.save!
      if @participant.player? && @participant.current_order&.id != @order.id
        raise ActiveRecord::RecordNotSaved, "The ticket was added to a different Order."
      end
    end
    redirect_to edit_admin_order_path(@order), notice: "Participant registered."
  rescue ActiveRecord::RecordInvalid
    render "participants/new", status: :unprocessable_entity
  rescue ActiveRecord::RecordNotSaved => e
    redirect_to edit_admin_order_path(@order), alert: e.message
  end

  private

  def set_order
    @order = Order.find(params[:order_id])
    @admin_basket = true
    redirect_to admin_order_path(@order), alert: "Only draft Orders can be edited." unless @order.editable?
  end
end
