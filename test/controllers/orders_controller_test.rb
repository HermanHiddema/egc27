require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  def with_mollie_simulation_enabled
    original = Rails.application.config.x.payments.simulate_mollie
    Rails.application.config.x.payments.simulate_mollie = true
    yield
  ensure
    Rails.application.config.x.payments.simulate_mollie = original
  end

  test "the basket page remains available without a draft order" do
    sign_in users(:one)

    get order_path

    assert_response :success
    assert_select "h1", "Shopping basket"
    assert_select "a", text: "Add participant ticket"
    assert_select "a", text: "Add hostel booking"
    assert_select "button[disabled]", text: "Book with commitment to pay"
  end

  test "the basket shows participant tickets and hostel bookings in separate sections" do
    sign_in users(:one)
    create_booking_for(users(:one))
    create_player_for(users(:one))

    get order_path

    assert_response :success
    assert_select "h2", text: "Participant tickets"
    assert_select "h2", text: "Hostel bookings"
    assert_select "h2", text: "Order summary"
  end

  test "development payment simulations are available from the basket checkout" do
    sign_in users(:one)
    create_player_for(users(:one))

    with_mollie_simulation_enabled do
      get order_path
    end

    assert_response :success
    assert_select "button", text: "Simulate paid"
    assert_select "button", text: "Simulate pending"
    assert_select "button", text: "Simulate failed"
    assert_select "button", text: "Simulate canceled"
  end

  test "a participant with an unpaid submitted order is directed there instead of getting a duplicate ticket" do
    sign_in users(:one)
    participant = participants(:three)

    assert_no_difference("Product.count") do
      post add_participant_order_path, params: { participant_id: participant.uuid }
    end

    assert_redirected_to submitted_order_path(orders(:three))
    assert_equal 1, participant.participant_tickets.count
  end

  test "an owner can remove a draft ticket while keeping the participant" do
    sign_in users(:one)
    participant = create_player_for(users(:one))
    ticket = participant.participant_tickets.sole
    product = ticket.product
    order = product.order

    delete remove_product_order_path(product_id: product.id)

    assert_redirected_to order_path
    assert Participant.exists?(participant.id)
    assert_not ParticipantTicket.exists?(ticket.id)
    assert_empty order.products.reload
  end

  test "a user cannot remove another user's product" do
    sign_in users(:one)

    assert_no_difference("Product.count") do
      delete remove_product_order_path(product_id: products(:two).id)
    end

    assert_response :not_found
  end

  test "editing an unpaid ticket recalculates its draft product price" do
    sign_in users(:one)
    participant = create_player_for(users(:one))
    ticket = participant.draft_ticket
    old_price = ticket.product.price_cents

    patch update_product_order_path(product_id: ticket.product.id), params: {
      participant: { age_group: "12-17", attendance_option: "weekend_only", participant_type: "visitor" }
    }

    assert_redirected_to order_path
    assert_equal "player", participant.reload.participant_type
    assert_equal "12-17", participant.age_group
    assert_equal "weekend_only", participant.attendance_option
    assert_not_equal old_price, ticket.product.reload.price_cents
  end

  test "a price change requires checkout confirmation before submission" do
    sign_in users(:one)
    order = users(:one).draft_order!
    create_player_for(users(:one))

    post submit_order_path, params: { confirmed_total_cents: 1 }

    assert_redirected_to order_path
    assert order.reload.draft?
    assert_empty order.payments
    assert_match "confirm checkout again", flash[:alert]
  end

  test "checkout reprices a hostel booking and requires confirmation of the new total" do
    sign_in users(:one)
    booking = nil
    travel_to Time.zone.local(2027, 1, 31, 12) do
      booking = create_booking_for(users(:one))
    end
    old_total = booking.product.price_cents

    travel_to Time.zone.local(2027, 2, 1, 12) do
      post submit_order_path, params: { confirmed_total_cents: old_total }
    end

    expected_total = 2 * 8_200
    assert_redirected_to order_path
    assert_match "confirm checkout again", flash[:alert]
    assert_equal expected_total, booking.reload.amount_cents
    assert_equal expected_total, booking.product.reload.price_cents
    assert booking.order.reload.draft?
    assert_empty booking.order.payments
  end

  test "past orders lists submitted orders and details their payment status" do
    sign_in users(:one)

    get submitted_orders_path

    assert_response :success
    assert_select "h1", "Past Orders"
    assert_select "a", text: "Order #{orders(:one).id}"

    get submitted_order_path(orders(:one))

    assert_response :success
    assert_select "h1", "Order #{orders(:one).id}"
    assert_select "h2", "Payment history"
    assert_select "p", text: /A payment is in progress/
  end

  test "checkout submits the full basket and starts a full amount payment" do
    sign_in users(:one)
    participant = create_player_for(users(:one))
    order = participant.draft_ticket.order
    total = order.total_cents

    with_mollie_simulation_enabled do
      post submit_order_path, params: { confirmed_total_cents: total, simulate_status: "paid" }
    end

    assert_response :redirect
    assert order.reload.submitted?
    assert_equal total, order.payments.sole.amount_cents
    assert order.payments.sole.paid?
  end

  test "pending payment prevents another attempt for a submitted order" do
    sign_in users(:one)
    order = orders(:one)
    payment_count = order.payments.count

    post pay_submitted_order_path(order)

    assert_redirected_to submitted_order_path(order)
    assert_equal payment_count, order.payments.count
    assert_match "already being processed", flash[:notice]
  end

  test "another user cannot view a submitted order" do
    sign_in users(:one)

    get submitted_order_path(orders(:two))

    assert_response :not_found
  end

  private

  def create_player_for(user)
    Participant.create!(
      user: user, first_name: "Alex", last_name: "Player", email: user.email,
      age_group: "18-49", gender: "male", country: "NL", club: "", participant_type: "player",
      accepted_terms_and_conditions: true, accepted_privacy_policy: true, image_use_consent: true
    )
  end

  def create_booking_for(user)
    user.hostel_bookings.create!(
      arrival_date: Date.new(2027, 7, 24), departure_date: Date.new(2027, 7, 26),
      double_rooms: 1
    )
  end
end
