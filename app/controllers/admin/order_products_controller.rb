class Admin::OrderProductsController < ApplicationController
  include ParticipantTicketEditing

  before_action :require_admin!
  before_action :set_product

  def edit
    render "orders/edit_product"
  end

  def update
    if update_participant_ticket(@product)
      redirect_to edit_admin_order_path(@order), notice: "Ticket details updated."
    else
      render "orders/edit_product", status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotSaved => e
    redirect_to admin_order_path(@order), alert: e.message
  end

  private

  def set_product
    @admin_basket = true
    @order = Order.find(params[:order_id])
    return redirect_to admin_order_path(@order), alert: "Only draft Orders can be edited." unless @order.editable?

    @product = @order.products.where(productable_type: "ParticipantTicket").find(params[:id])
    @participant = @product.productable.participant
    head :not_found unless @participant.user_id == @order.user_id
  end
end
