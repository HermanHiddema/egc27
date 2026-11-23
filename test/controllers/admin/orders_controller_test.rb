require "test_helper"

class Admin::OrdersControllerTest < ActionDispatch::IntegrationTest
  test "order products link to participant ticket and participant details" do
    sign_in users(:admin)
    ticket = participant_tickets(:three)
    participant = ticket.participant

    get admin_order_path(ticket.order)

    assert_response :success
    assert_select "a[href=?]", admin_participant_ticket_path(ticket), text: "Participant ticket ##{ticket.id}"
    assert_select "a[href=?]", admin_participant_path(participant), text: "#{participant.first_name} #{participant.last_name}"
    assert_select "p", text: "#{CongressPassPricing.new(attendance_option: participant.attendance_option).attendance_label} · age #{participant.age_group}"
    assert_select "a[href=?]", edit_admin_participant_path(participant), count: 0
    assert_match(/Participant ticket ##{ticket.id}<\/a>\s+for\s+<a/, response.body)
  end

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

  test "invalid or stale return Orders are ignored and cancellation falls back to the overview" do
    sign_in users(:admin)
    deleted_draft = users(:admin).orders.create!(status: "draft")
    deleted_draft.destroy!

    [deleted_draft.id, orders(:one).id, "https://example.com"].each do |return_id|
      get admin_order_path(orders(:three)), params: { return_order_id: return_id }
      assert_response :success
      assert_select "input[name='return_order_id']", count: 0
      assert_select "a[href='#{admin_orders_path}']", text: "Orders"
    end

    patch cancel_admin_order_path(orders(:three)), params: { return_order_id: deleted_draft.id }

    assert_redirected_to admin_orders_path
    assert orders(:three).reload.cancelled?
  end

  test "failed cancellation keeps the draft return link on the unpaid Order" do
    sign_in users(:admin)
    draft = users(:admin).orders.create!(status: "draft")
    order = orders(:one)

    patch cancel_admin_order_path(order), params: { return_order_id: draft.id }

    assert_redirected_to admin_order_path(order, return_order_id: draft.id)
    assert_not order.reload.cancelled?
    follow_redirect!
    assert_select "[role='alert']", text: /Order could not be cancelled/
    assert_select "a[href='#{new_participant_admin_order_path(draft)}']", text: "Back to adding participants to Order ##{draft.id}"
  end

  test "deleting a linked unpaid draft returns to the original draft participant selection" do
    sign_in users(:admin)
    draft = users(:admin).orders.create!(status: "draft")
    unpaid_draft = users(:two).orders.create!(status: "draft")
    get admin_order_path(unpaid_draft), params: { return_order_id: draft.id }
    assert_select "form[action='#{discard_admin_order_path(unpaid_draft)}']" do
      assert_select "input[name='return_order_id'][value='#{draft.id}']"
    end

    assert_difference "Order.count", -1 do
      delete discard_admin_order_path(unpaid_draft), params: { return_order_id: draft.id }
    end

    assert_redirected_to new_participant_admin_order_path(draft)
    assert draft.reload.editable?
  end

  test "the order date column is labeled as a creation date" do
    sign_in users(:admin)

    get admin_orders_path

    assert_response :success
    assert_select "th", text: /Created/
  end

  test "draft and submitted orders have distinct sections with filters in the submitted section" do
    sign_in users(:admin)
    users(:admin).orders.create!(status: "draft")

    get admin_orders_path

    assert_response :success
    assert_select "section h2", text: "Orders still in draft"
    assert_select "section[aria-labelledby='submitted-orders-heading']" do
      assert_select "h2#submitted-orders-heading", text: "Submitted Orders"
      assert_select "form[action='#{admin_orders_path}'] input[name='status[]']"
      assert_select "table"
    end
  end

  test "order details return to the selected overview sort and filters" do
    sign_in users(:admin)
    order = orders(:three)
    overview = { sort: "total", direction: "asc", status: %w[awaiting failed] }

    get admin_orders_path, params: overview

    assert_response :success
    assert_select "a[href=?]", admin_order_path(order, **overview), text: "##{order.id}"

    get admin_order_path(order), params: overview

    assert_response :success
    assert_select "a[href=?]", admin_orders_path(**overview), text: "Orders"

    get admin_orders_path, params: overview
    assert_select "input#status_awaiting[checked]"
    assert_select "input#status_failed[checked]"
    assert_select "th a", text: /Total.*↑/
  end

  test "order detail return links ignore invalid overview parameters" do
    sign_in users(:admin)

    get admin_order_path(orders(:three)), params: { sort: "invalid", direction: "invalid", status: %w[awaiting invalid], return_to: "https://example.com" }

    assert_response :success
    assert_select "a[href=?]", admin_orders_path(status: ["awaiting"]), text: "Orders"
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

  test "cancellation confirmations describe the products on both Order pages" do
    sign_in users(:admin)
    user = users(:one)
    2.times do |index|
      user.participants.create!(
        first_name: "Player#{index}", last_name: "Example", email: user.email, country: "NL", club: "Club",
        age_group: "18-49", gender: "female", attendance_option: "weekend_only", image_use_consent: true
      )
      user.hostel_bookings.create!(arrival_date: "2027-07-24", departure_date: "2027-07-25", single_rooms: 1)
    end
    mixed = user.orders.drafts.sole
    mixed.submit!
    hostel_only = users(:admin).hostel_bookings.create!(arrival_date: "2027-07-24", departure_date: "2027-07-25", single_rooms: 1).order
    hostel_only.submit!
    ticket_only = orders(:three)

    messages = {
      mixed => "Cancel Order #{mixed.id} containing 2 Participant tickets and 2 Hostel bookings? Participant registrations will be kept.",
      hostel_only => "Cancel Order #{hostel_only.id} containing 1 Hostel booking? Participant registrations will be kept.",
      ticket_only => "Cancel Order #{ticket_only.id} containing 1 Participant ticket? Participant registrations will be kept."
    }

    get admin_orders_path
    assert_response :success
    messages.each do |order, message|
      assert_select "form[action='#{cancel_admin_order_path(order)}'][data-controller='order-cancellation'][data-order-cancellation-message-value=?]", message
    end
    assert_select "dialog#order-cancellation-dialog" do
      assert_select "button", text: "OK"
      assert_select "button", text: "Do not cancel"
    end

    messages.each do |order, message|
      get admin_order_path(order)
      assert_response :success
      assert_select "form[action='#{cancel_admin_order_path(order)}'][data-controller='order-cancellation'][data-order-cancellation-message-value=?]", message
    end
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
