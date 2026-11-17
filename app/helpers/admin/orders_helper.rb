module Admin::OrdersHelper
  def admin_order_product_label(product)
    item = product.productable
    if item.is_a?(ParticipantTicket)
      "Participant ticket: #{item.participant.first_name} #{item.participant.last_name}"
    else
      item.description
    end
  end
end
