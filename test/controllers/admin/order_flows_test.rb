require "test_helper"

class Admin::OrderFlowsTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin) }

  def ticketless_participant
    participant = participants(:three).dup
    participant.uuid = SecureRandom.uuid
    participant.egd_pin = nil
    participant.save!
    participant.current_order.destroy!
    participant.reload
  end

  test "creating an order for a user with a draft leaves their basket unchanged" do
    owner = users(:one)
    draft = owner.orders.create!(status: "draft")
    assert_no_difference ["Order.count", "Product.count"] do
      post admin_orders_path, params: { order: { user_id: owner.id } }
    end
    assert_redirected_to edit_admin_order_path(draft)
    assert_empty draft.products
  end

  test "admin can create and review an empty draft for another user" do
    assert_difference "Order.count", 1 do
      post admin_orders_path, params: { order: { user_id: users(:two).id } }
    end
    order = Order.last
    assert_equal users(:two), order.user
    get edit_admin_order_path(order)
    assert_response :success
  end

  test "the participant shortcut reuses the unpaid order" do
    participant = participants(:three)
    assert_no_difference ["Order.count", "ParticipantTicket.count"] do
      post add_payment_admin_participant_path(participant)
    end
    assert_redirected_to new_admin_order_payment_path(orders(:three))
    get new_admin_order_payment_path(orders(:three))
    assert_response :success
    assert_select "body", text: /#{participant.first_name}/
  end

  test "the participant shortcut creates one ticket in a new order" do
    participant = ticketless_participant
    assert_difference ["Order.count", "Product.count", "ParticipantTicket.count"], 1 do
      post add_payment_admin_participant_path(participant)
    end
    order = participant.reload.current_order
    assert_redirected_to edit_admin_order_path(order)
    assert_equal participant.user, order.user
    assert_equal participant, order.products.sole.productable.participant
  end

  test "the participant shortcut does not change another user's existing draft" do
    participant = ticketless_participant
    draft = participant.user.orders.create!(status: "draft")
    assert_no_difference ["Order.count", "Product.count", "ParticipantTicket.count"] do
      post add_payment_admin_participant_path(participant)
    end
    assert_redirected_to edit_admin_order_path(draft)
    assert_empty draft.products
  end

  test "multiple participants belonging to the same user can be added" do
    first = ticketless_participant
    second = ticketless_participant
    assert_difference ["Product.count", "ParticipantTicket.count"], 2 do
      post admin_orders_path, params: { order: { user_id: first.user_id, participant_ids: [first.id, second.id] } }
    end
    order = first.reload.current_order
    assert_equal order, second.reload.current_order
    assert_equal first.user_id, order.user_id
    get edit_admin_order_path(order)
    assert_response :success
  end

  test "manual payment records the full order total" do
    order = orders(:three)
    get new_admin_order_payment_path(order)
    order.reload
    assert_difference "Payment.count", 1 do
      post admin_order_payments_path(order), params: { confirmed_total_cents: order.total_cents, payment: {
        amount_eur: format("%.2f", order.total_cents / 100.0), description: "Cash", payment_method: "cash", payment_date: Date.current
      } }
    end
    assert_redirected_to admin_order_path(order)
    assert_equal "manual", order.payments.order(:id).last.provider
  end

  test "a pending payment blocks manual payment" do
    order = orders(:three)
    order.payments.create!(status: "open", amount_cents: order.total_cents, description: "Mollie")
    assert_no_difference "Payment.count" do
      post admin_order_payments_path(order), params: { confirmed_total_cents: order.total_cents, payment: {
        amount_eur: format("%.2f", order.total_cents / 100.0), description: "Cash", payment_method: "cash", payment_date: Date.current
      } }
    end
    assert_response :unprocessable_entity
  end

  test "admin creates a provisional hostel booking for another user" do
    order = users(:two).orders.create!(status: "draft")
    get new_admin_order_hostel_booking_path(order)
    assert_response :success
    assert_difference ["HostelBooking.count", "Product.count"], 1 do
      post admin_order_hostel_bookings_path(order), params: { hostel_booking: {
        arrival_date: "2027-07-24", departure_date: "2027-07-26", single_rooms: 1, double_rooms: 0,
        six_person_rooms: 0, mixed_dorm_beds: 0, female_dorm_beds: 0, breakfasts: 0
      } }
    end
    assert_redirected_to edit_admin_order_path(order)
    assert_equal users(:two), order.products.sole.productable.user
  end

  test "admin can change the owner of a hostel-only draft and its bookings" do
    order = users(:admin).orders.create!(status: "draft")
    post admin_order_hostel_bookings_path(order), params: { hostel_booking: {
      arrival_date: "2027-07-24", departure_date: "2027-07-26", single_rooms: 1, double_rooms: 0,
      six_person_rooms: 0, mixed_dorm_beds: 0, female_dorm_beds: 0, breakfasts: 0
    } }
    booking = order.products.sole.productable
    original_price = order.total_cents

    patch admin_order_path(order), params: { order: { user_id: users(:two).id } }

    assert_redirected_to edit_admin_order_path(order)
    assert_equal users(:two), order.reload.user
    assert_equal users(:two), booking.reload.user
    assert_equal original_price, order.total_cents
  end

  test "adding a ticket for another user assigns the empty draft to that user" do
    participant = ticketless_participant
    order = users(:admin).orders.create!(status: "draft")

    post add_participant_admin_order_path(order), params: { participant_id: participant.id }

    assert_redirected_to edit_admin_order_path(order)
    assert_equal participant.user, order.reload.user
    assert_equal participant, order.products.sole.productable.participant
  end

  test "participant search supports prefix matches and a non-JavaScript form" do
    order = users(:admin).orders.create!(status: "draft")

    get participants_admin_order_path(order), params: { q: "Car" }, as: :json
    assert_response :success
    assert_includes response.parsed_body.map { |entry| entry.fetch("id") }, participants(:three).id
    assert_operator response.parsed_body.size, :<=, 10

    get participants_admin_order_path(order), params: { q: "Car" }
    assert_response :success
    assert_select "select[name='participant_id'] option[value='#{participants(:three).id}']", text: /Carol/
  end

  test "search and ticket addition enforce the existing ticket owner's user" do
    participant = ticketless_participant
    other_participant = participants(:two).dup
    other_participant.uuid = SecureRandom.uuid
    other_participant.egd_pin = nil
    other_participant.save!
    other_participant.current_order.destroy!
    other_participant.reload
    order = users(:one).orders.create!(status: "draft")
    participant.add_ticket_to_draft_order!

    get participants_admin_order_path(order), params: { q: "Bob" }, as: :json
    assert_response :success
    assert_empty response.parsed_body

    assert_no_difference "ParticipantTicket.count" do
      post add_participant_admin_order_path(order), params: { participant_id: other_participant.id }
    end
    assert_redirected_to edit_admin_order_path(order)
    assert_match(/same user/, flash[:alert])
    assert_equal users(:one), order.reload.user
    assert_equal 1, order.products.count
  end

  test "changing owner does not modify an existing draft of the target user" do
    order = users(:admin).orders.create!(status: "draft")
    other_draft = users(:two).orders.create!(status: "draft")

    patch admin_order_path(order), params: { order: { user_id: users(:two).id } }

    assert_redirected_to edit_admin_order_path(order)
    follow_redirect!
    assert_select "a[href='#{edit_admin_order_path(other_draft)}']", text: /Review existing draft/
    assert_equal users(:admin), order.reload.user
    assert_empty other_draft.products
  end

  test "a ticket for a different owner is rejected without changing either basket" do
    order = users(:two).orders.create!(status: "draft")
    assert_no_difference ["Product.count", "ParticipantTicket.count"] do
      patch admin_order_path(order), params: { order: { user_id: order.user_id, participant_ids: [participants(:three).id] } }
    end
    assert_response :unprocessable_entity
    assert_empty order.products
  end

  test "an order owner cannot be changed while products exist" do
    order = orders(:three)
    order.user = users(:two)
    assert_not order.valid?
    assert_includes order.errors[:user], "cannot change while the order contains products"
  end

  test "manual payment ignores a submitted amount and uses the full order total" do
    order = orders(:three)
    get new_admin_order_payment_path(order)
    order.reload
    assert_difference "Payment.count", 1 do
      post admin_order_payments_path(order), params: { confirmed_total_cents: order.total_cents, payment: {
        amount_eur: "1.00", description: "Cash", payment_method: "cash", payment_date: Date.current
      } }
    end
    assert_redirected_to admin_order_path(order)
    assert_equal order.total_cents, order.payments.order(:id).last.amount_cents
  end

  test "manual payment rejects a future payment date with an explanation" do
    order = orders(:three)
    get new_admin_order_payment_path(order)
    order.reload

    assert_no_difference "Payment.count" do
      post admin_order_payments_path(order), params: { confirmed_total_cents: order.total_cents, payment: {
        description: "Cash", payment_method: "cash", payment_date: Date.current + 1.day
      } }
    end

    assert_response :unprocessable_entity
    assert_select "li", text: "Payment date cannot be in the future"
  end

  test "an already paid order cannot receive another payment" do
    order = orders(:three)
    order.payments.create!(status: "paid", provider: "manual", payment_method: "cash", payment_date: Date.current,
      amount_cents: order.total_cents, description: "First payment")
    assert_no_difference "Payment.count" do
      post admin_order_payments_path(order), params: { confirmed_total_cents: order.total_cents, payment: {
        amount_eur: format("%.2f", order.total_cents / 100.0), description: "Cash", payment_method: "cash", payment_date: Date.current
      } }
    end
    assert_response :unprocessable_entity
  end

  test "a non-admin cannot create orders or record payments" do
    sign_out users(:admin)
    sign_in users(:one)
    assert_no_difference ["Order.count", "Payment.count"] do
      post admin_orders_path, params: { order: { user_id: users(:one).id } }
      assert_redirected_to root_path
      post admin_order_payments_path(orders(:three)), params: { payment: { amount_eur: "1.00" } }
      assert_redirected_to root_path
    end
  end
end
