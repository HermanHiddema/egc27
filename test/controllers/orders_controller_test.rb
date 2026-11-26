require "test_helper"
require "ostruct"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  def with_mollie_simulation_enabled
    original = Rails.application.config.x.payments.simulate_mollie
    Rails.application.config.x.payments.simulate_mollie = true
    yield
  ensure
    Rails.application.config.x.payments.simulate_mollie = original
  end

  def with_mollie_get(remote)
    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| remote }
    yield
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end

  test "the basket page remains available without a draft order" do
    sign_in users(:one)

    assert_no_difference "Order.count" do
      get order_path
    end

    assert_response :success
    assert_select "h1", "Shopping basket"
    assert_select "a", text: "Add participant ticket"
    assert_select "a", text: "Add hostel booking"
    assert_select "button[disabled]", text: "Book with commitment to pay"
  end

  test "prefetching the basket and opening participant selection do not create a draft" do
    sign_in users(:one)

    assert_no_difference "Order.count" do
      get order_path, headers: { "X-Sec-Purpose" => "prefetch" }
      assert_response :success
      get new_participant_order_path
      assert_response :success
    end
    assert_empty users(:one).orders.drafts
  end

  test "adding an existing participant creates a draft only when adding the ticket" do
    sign_in users(:one)
    participant = create_player_for(users(:one))
    participant.draft_ticket.order.destroy!

    assert_difference ["Order.count", "Product.count", "ParticipantTicket.count"], 1 do
      post add_participant_order_path, params: { participant_id: participant.uuid }
    end

    assert_redirected_to order_path
    order = users(:one).orders.drafts.sole
    assert_equal participant, order.products.sole.productable.participant
  end

  test "invalid ticket additions do not leave an empty draft" do
    sign_in users(:one)

    assert_no_difference ["Order.count", "Product.count", "ParticipantTicket.count"] do
      post add_participant_order_path, params: { participant_id: participants(:visitor_one).uuid }
    end

    assert_redirected_to order_path
    assert_match "cannot purchase another ticket", flash[:alert]
    assert_empty users(:one).orders.drafts
  end

  test "stale basket mutations do not create a replacement draft" do
    sign_in users(:one)

    assert_no_difference "Order.count" do
      post submit_order_path
      assert_response :not_found
      delete empty_order_path
      assert_response :not_found
      delete cancel_order_path
      assert_response :not_found
    end
  end

  test "mobile navigation shows the basket count beside search" do
    sign_in users(:one)

    get order_path
    assert_select "div.lg\\:hidden [data-controller='search-toggle'] > a[aria-label='Shopping basket'] + button[aria-label='Search']"
    assert_select "div.lg\\:hidden [data-controller='search-toggle'] > a[title='Shopping basket'] span", count: 0

    create_player_for(users(:one))
    get order_path
    assert_select "div.lg\\:hidden [data-controller='search-toggle'] > a[aria-label='Shopping basket, 1 product'] span", text: "1"
  end

  test "canceled order detail shows a red status badge" do
    booking = create_booking_for(users(:one))
    booking.order.submit!
    booking.order.cancel!
    sign_in users(:one)

    get submitted_order_path(booking.order)

    assert_response :success
    assert_select "span.border-red-200.bg-red-50.text-red-800", text: "Order canceled"
  end

  test "submitted order links the hostel booking name and number to its details" do
    booking = create_booking_for(users(:one))
    booking.order.submit!
    sign_in users(:one)

    get submitted_order_path(booking.order)

    assert_response :success
    assert_select "a[href=?]", hostel_booking_path(booking), text: /Hostel booking ##{booking.id}/
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

    assert_no_difference ["Order.count", "Product.count"] do
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

  test "ticket country editing uses the country autocomplete and submits its ISO code" do
    sign_in users(:one)
    participant = create_player_for(users(:one))
    ticket = participant.draft_ticket

    get edit_product_order_path(product_id: ticket.product.id)

    assert_response :success
    assert_select 'form[data-controller="egd-autocomplete"]'
    assert_select 'input[type="hidden"][name="participant[country]"][value="NL"]'
    assert_select 'input#order_participant_country_display[role="combobox"]'
    assert_select '[data-egd-autocomplete-target="countryOptions"]'
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
    assert_select "h1", "My Orders"
    assert_select "p", text: /Created/
    assert_select "article[data-controller='clickable-row'][data-action='click->clickable-row#navigate'][data-clickable-row-url-value=?]", submitted_order_path(orders(:one)) do
      assert_select "a[href=?]", submitted_order_path(orders(:one)), text: "Order #{orders(:one).id}"
      assert_select "a[href=?]", submitted_order_path(orders(:one)), text: "View order"
      assert_select "form[action=?] button", pay_submitted_order_path(orders(:one)), text: "Continue payment"
    end

    get submitted_order_path(orders(:one))

    assert_response :success
    assert_select "h1", "Order #{orders(:one).id}"
    assert_select "h2", "Payment"
    assert_select "button", text: "Continue payment"
  end

  test "past orders shows current mixed order prices and confirms them before retry" do
    sign_in users(:one)
    order = nil
    old_total = nil
    travel_to Time.zone.local(2027, 1, 31, 12) do
      participant = create_player_for(users(:one))
      create_booking_for(users(:one))
      order = participant.draft_ticket.order
      order.submit!
      old_total = order.total_cents
      order.payments.create!(status: "failed", amount_cents: old_total, description: "Failed attempt")
    end

    travel_to Time.zone.local(2027, 2, 1, 12) do
      expected_total = 26_000 + 2 * 8_200
      with_mollie_simulation_enabled do
        get submitted_orders_path

        assert_response :success
        assert_select "p", text: /The total has changed since the last payment attempt/
        assert_select "form[action='#{pay_submitted_order_path(order)}'] input[name='confirmed_total_cents'][value='#{expected_total}']"
        assert_equal old_total, order.total_cents

        post pay_submitted_order_path(order), params: { confirmed_total_cents: expected_total, simulate_status: "paid" }
      end

      assert_equal expected_total, order.total_cents
      assert_equal expected_total, order.payments.order(:id).last.amount_cents
      assert order.payments.order(:id).last.paid?
    end
  end

  test "past orders loads retry prices without queries per order" do
    sign_in users(:one)
    create_player_for(users(:one)).draft_ticket.order.submit!
    get submitted_orders_path

    count_queries = lambda do
      sql_queries = []
      subscriber = lambda do |_name, _start, _finish, _id, payload|
        sql = payload[:sql]
        sql_queries << sql if sql.match?(/\ASELECT\b.*\bFROM "(?:orders|products|payments|participant_tickets|participants)"/im)
      end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { get submitted_orders_path }
      assert_response :success
      sql_queries.length
    end

    initial_count = count_queries.call
    2.times { create_player_for(users(:one)).draft_ticket.order.submit! }
    assert_equal initial_count, count_queries.call
  end

  test "retry requires reviewing the total if prices change after the overview is shown" do
    sign_in users(:one)
    order = nil
    displayed_total = nil
    travel_to Time.zone.local(2027, 1, 31, 12) do
      order = create_player_for(users(:one)).draft_ticket.order
      order.submit!
      displayed_total = order.total_cents
      order.payments.create!(status: "failed", amount_cents: displayed_total, description: "Failed attempt")
      get submitted_orders_path
      assert_select "form[action='#{pay_submitted_order_path(order)}'] input[name='confirmed_total_cents'][value='#{displayed_total}']"
    end

    travel_to Time.zone.local(2027, 2, 1, 12) do
      assert_no_difference("Payment.count") do
        post pay_submitted_order_path(order), params: { confirmed_total_cents: displayed_total }
      end
      assert_redirected_to submitted_order_path(order)
      assert_match "review the updated total", flash[:alert]
      assert_equal 26_000, order.total_cents
    end
  end

  test "past orders keeps an open payment's protected amount" do
    sign_in users(:one)
    order = orders(:one)

    travel_to Time.zone.local(2027, 2, 1, 12) do
      get submitted_orders_path
      assert_select "form[action='#{pay_submitted_order_path(order)}'] input[name='confirmed_total_cents'][value='19000']"
    end

    assert_equal 19_000, order.total_cents
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
    assert_empty users(:one).orders.drafts

    assert_no_difference "Order.count" do
      follow_redirect!
      assert_response :success
      get order_path, headers: { "X-Sec-Purpose" => "prefetch" }
      assert_response :success
      get submitted_orders_path
      assert_response :success
    end
    assert_empty users(:one).orders.drafts
  end

  test "pending payment prevents another attempt for a submitted order" do
    sign_in users(:one)
    order = orders(:one)
    payments(:open_payment).update!(status: "pending")
    payment_count = order.payments.count

    post pay_submitted_order_path(order)

    assert_redirected_to submitted_order_path(order)
    assert_equal payment_count, order.payments.count
    assert_match "already being processed", flash[:notice]
  end

  test "open Mollie payment can be resumed from both Order pages without another attempt" do
    sign_in users(:one)
    order = orders(:one)
    payment = payments(:open_payment)
    remote = OpenStruct.new(id: payment.mollie_payment_id, status: "open", checkout_url: "https://example.test/checkout")

    get submitted_orders_path
    assert_select "form[action='#{pay_submitted_order_path(order)}'] button", text: "Continue payment"
    assert_select "p", text: "Payment open"
    get submitted_order_path(order)
    assert_select "button", text: "Continue payment"
    get participant_path(participants(:one))
    assert_match "Payment open", response.body
    assert_select "a[href='#{submitted_order_path(order)}']", text: "View Order #{order.id}"

    with_mollie_get(remote) do
      get success_payments_path(token: payment.return_token)
      assert_select "a[href='#{submitted_order_path(order)}']", text: "Continue payment"
      assert_no_difference("Payment.count") do
        post pay_submitted_order_path(order), params: { confirmed_total_cents: order.total_cents }
      end
    end

    assert_redirected_to "https://example.test/checkout"
    assert_equal "open", payment.reload.status
  end

  test "a payment that became pending or authorized at Mollie cannot be resumed or duplicated" do
    sign_in users(:one)
    order = orders(:one)
    payment = payments(:open_payment)

    %w[pending authorized].each do |status|
      payment.update!(status: "open")
      remote = OpenStruct.new(id: payment.mollie_payment_id, status:, checkout_url: "https://example.test/checkout")
      with_mollie_get(remote) do
        assert_no_difference("Payment.count") { post pay_submitted_order_path(order) }
      end
      assert_redirected_to submitted_order_path(order)
      assert_equal status, payment.reload.status

      get submitted_order_path(order)
      assert_select "button", { text: "Continue payment", count: 0 }
      assert_no_difference("Payment.count") { post pay_submitted_order_path(order) }
      assert_match "already being processed", flash[:notice]
    end
  end

  test "an expired Mollie checkout returns to Order review without creating a payment" do
    sign_in users(:one)
    order = orders(:one)
    payment = payments(:open_payment)
    remote = OpenStruct.new(id: payment.mollie_payment_id, status: "expired", checkout_url: nil)

    with_mollie_get(remote) do
      assert_no_difference("Payment.count") { post pay_submitted_order_path(order) }
    end

    assert_redirected_to submitted_order_path(order)
    assert_match "review the Order total", flash[:notice]
    assert_equal "expired", payment.reload.status
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
  test "outstanding notification can be dismissed without hiding badges and returns for new orders" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    sign_in users(:one)
    get submitted_orders_path(outstanding: 1)
    assert_response :success
    assert_select "a", text: "Review outstanding Orders"
    assert_select '#user-menu [aria-label*="outstanding Order"].bg-red-100', text: /\d+ unpaid/
    assert_select "[role=status].bg-blue-50.text-blue-800", text: /You have 2 unpaid orders/
    assert_select "[role=status] svg[aria-hidden=true]"
    assert_select 'button.cursor-pointer[aria-label="Dismiss outstanding Orders notification"]'
    assert_select ".flex.justify-end a.btn-primary", text: "Show all Orders"
    assert_select "a", text: "Order #{orders(:one).id}"
    assert_select "a", text: "Order #{orders(:two).id}", count: 0

    assert_no_difference ["Order.count", "Payment.count"] do
      post dismiss_outstanding_notification_path
    end
    assert_equal [orders(:one).id, orders(:three).id].sort,
      Rails.cache.read("users/#{users(:one).id}/dismissed_outstanding_order_ids").sort
    assert_no_match(/outstanding_orders_#{users(:one).id}/, response.headers["Set-Cookie"].to_s)
    get submitted_orders_path
    assert_select "a", text: "Review outstanding Orders", count: 0
    assert_select '#user-menu [aria-label*="outstanding Order"]'

    Order.where(id: orders(:two).id).update_all(user_id: users(:one).id)
    Payment.where(order_id: orders(:two).id).update_all(status: "failed")
    get submitted_orders_path
    assert_select "a", text: "Review outstanding Orders"
  ensure
    Rails.cache = original_cache
  end

  test "paid orders have no notification and payment summary retains reversals" do
    sign_in users(:two)
    Payment.where(id: payments(:paid_payment).id).update_all(amount_refunded_cents: 1000, amount_charged_back_cents: 500)
    get submitted_orders_path(outstanding: 1)
    assert_select "a", text: "Review outstanding Orders", count: 0
    assert_select '#user-menu [aria-label*="outstanding Order"]', count: 0
    assert_select "a", text: "Order #{orders(:two).id}", count: 0
    get submitted_order_path(orders(:two))
    assert_select "p", text: /Refunded: € 10.00/
    assert_select "p", text: /Chargeback: € 5.00/
  end

  test "payment summary highlights latest attempt and collapses older attempts" do
    sign_in users(:one)
    order = orders(:one)
    Payment.where(id: payments(:open_payment).id).update_all(status: "failed")
    Payment.create!(order: order, amount_cents: order.total_cents, description: "Second attempt", status: "expired")
    get submitted_orders_path
    assert_select "article", text: /Expired/
    assert_select "summary", text: "Previous payment attempts", count: 0

    get submitted_order_path(order)
    assert_select ".text-base", text: /Expired/
    assert_select "details:not([open]) summary", "Previous payment attempts"
    assert_select "details", text: /Failed/
    assert_select "button", text: "Retry payment"
  end
end
