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
end
