module Admin::OrdersHelper
  def admin_order_history_event(version)
    changes = version.changeset || {}
    case version.item_type
    when "Order"
      return "Order created" if version.event == "create"
      return "Draft Order deleted" if version.event == "destroy"
      return "Order canceled" if changes.dig("cancelled_at")&.last.present?
      return "Order submitted" if changes.dig("status")&.last == "submitted"
      return "Order owner changed" if changes.key?("user_id")

      "Order updated"
    when "Product"
      case version.event
      when "create" then "Product ##{version.item_id} added"
      when "destroy" then "Product ##{version.item_id} removed"
      when "item_updated" then "Product ##{version.item_id} details updated"
      else "Product ##{version.item_id} updated"
      end
    when "Payment"
      version.event == "create" ? "Payment ##{version.item_id} recorded" : "Payment ##{version.item_id} updated"
    else
      "#{version.item_type} ##{version.item_id} #{version.event}"
    end
  end

  def admin_orders_overview_params
    overview = {}
    overview[:sort] = params[:sort] if Admin::OrdersController::SORT_COLUMNS.include?(params[:sort])
    overview[:direction] = params[:direction] if %w[asc desc].include?(params[:direction])
    statuses = params[:status].is_a?(Array) ? params[:status] : [params[:status]]
    statuses = statuses.select { |status| Admin::OrdersController::STATUS_FILTERS.include?(status) }.uniq
    overview[:status] = statuses if statuses.any?
    overview
  end

  def admin_order_cancellation_message(order)
    counts = order.products.to_a.group_by(&:productable_type).transform_values(&:size)
    items = []
    items << pluralize(counts["ParticipantTicket"], "Participant ticket") if counts["ParticipantTicket"].to_i.positive?
    items << pluralize(counts["HostelBooking"], "Hostel booking") if counts["HostelBooking"].to_i.positive?
    contents = items.any? ? " containing #{items.to_sentence}" : ""

    "Cancel Order #{order.id}#{contents}? Participant registrations will be kept."
  end

  def admin_order_product_label(product)
    item = product.productable
    if item.is_a?(ParticipantTicket)
      "Participant ticket: #{item.participant.first_name} #{item.participant.last_name}"
    else
      item.description
    end
  end
end
