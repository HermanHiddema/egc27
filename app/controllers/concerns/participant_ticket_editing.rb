module ParticipantTicketEditing
  extend ActiveSupport::Concern

  private

  def update_participant_ticket(product)
    participant = product.productable.participant
    attributes = if participant.valid_admission?
      params.require(:participant).permit(:gender, :country, :club, :image_use_consent)
    else
      params.require(:participant).permit(:first_name, :last_name, :gender, :age_group, :country, :club,
        :image_use_consent, :attendance_option, :rank, :egd_pin, :phone)
    end

    @order.with_lock do
      raise ActiveRecord::RecordNotSaved, "Only tickets in a draft basket can be edited." unless @order.editable?
      raise ActiveRecord::RecordNotSaved, "Ticket must belong to the Order owner." unless participant.user_id == @order.user_id

      participant.update(attributes).tap do |saved|
        OrderRepricingService.call(order: @order, date: Date.current) if saved
      end
    end
  end
end
