require "test_helper"

class Admin::OrdersControllerTest < ActionDispatch::IntegrationTest
  test "an admin can cancel an unpaid order while preserving history and recording the actor" do
    sign_in users(:admin)
    order = orders(:three)
    ticket = participant_tickets(:three)
    payment = order.payments.create!(status: "failed", amount_cents: order.total_cents, description: "Failed attempt")

    patch cancel_admin_order_path(order)

    assert_redirected_to admin_orders_path
    assert order.reload.cancelled?
    assert ticket.reload.invalidated_at
    assert_equal payment, order.payments.reload.sole
    assert_equal users(:admin).id.to_s, order.versions.reload.last.whodunnit
  end

  test "a non-admin cannot cancel an order" do
    sign_in users(:one)
    order = orders(:three)
    ticket = participant_tickets(:three)

    patch cancel_admin_order_path(order)

    assert_redirected_to root_path
    assert_not order.reload.cancelled?
    assert_nil ticket.reload.invalidated_at
  end

  test "the order date column is labeled as a creation date" do
    sign_in users(:admin)

    get admin_orders_path

    assert_response :success
    assert_select "th", text: /Created/
  end

  test "manual payment action is shown for an unpaid order on the list and details" do
    sign_in users(:admin)
    order = orders(:three)

    get admin_orders_path
    assert_select "a[href='#{new_admin_order_payment_path(order)}']", text: "Add payment"
    assert_select "form[action='#{cancel_admin_order_path(order)}'] button", text: "Cancel order"

    get admin_order_path(order)
    assert_select "a[href='#{new_admin_order_payment_path(order)}']", text: "Add payment"
  end

  test "manual payment action is hidden while a payment is open, pending or authorized" do
    sign_in users(:admin)
    order = orders(:three)
    payment = order.payments.create!(status: "open", amount_cents: order.total_cents, description: "Mollie")

    %w[open pending authorized].each do |status|
      payment.update!(status: status)
      get admin_orders_path
      assert_select "a[href='#{new_admin_order_payment_path(order)}']", count: 0
      get admin_order_path(order)
      assert_select "a[href='#{new_admin_order_payment_path(order)}']", count: 0
    end
  end
end
