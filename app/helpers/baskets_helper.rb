module BasketsHelper
  def basket_return_path
    @admin_basket ? edit_admin_order_path(@order) : order_path
  end

  def basket_registration_path
    @admin_basket ? new_admin_order_participant_path(@order) : new_participant_path(return_to: order_path)
  end

  def basket_update_product_path
    @admin_basket ? admin_order_product_path(@order, @product) : update_product_order_path(product_id: @product.id)
  end

  def basket_participant_path(order, participant, admin: false)
    admin ? edit_admin_participant_path(participant) : participant_path(participant)
  end

  def basket_edit_product_path(order, product, admin: false)
    admin ? edit_admin_order_product_path(order, product) : edit_product_order_path(product_id: product.id)
  end

  def basket_remove_product_path(order, product, admin: false)
    admin ? remove_product_admin_order_path(order, product_id: product.id) : remove_product_order_path(product_id: product.id)
  end

  def basket_booking_path(order, booking, admin: false)
    admin ? edit_admin_order_hostel_booking_path(order, booking) : hostel_booking_path(booking)
  end

  def basket_edit_booking_path(order, booking, admin: false)
    admin ? edit_admin_order_hostel_booking_path(order, booking) : edit_hostel_booking_path(booking)
  end
end
