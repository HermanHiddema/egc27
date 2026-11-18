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
    assert_response :unprocessable_entity
    assert_select "[role='alert'] a[href='#{admin_order_path(draft)}']", text: "Order ##{draft.id}"
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
    post admin_orders_path, params: { order: { user_id: first.user_id } }
    order = Order.last
    assert_difference ["Product.count", "ParticipantTicket.count"], 2 do
      post add_participant_admin_order_path(order), params: { participant_id: first.id }
      post add_participant_admin_order_path(order), params: { participant_id: second.id }
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

  test "admin confirms changing the owner and clearing provisional hostel bookings" do
    order = users(:admin).orders.create!(status: "draft")
    post admin_order_hostel_bookings_path(order), params: { hostel_booking: {
      arrival_date: "2027-07-24", departure_date: "2027-07-26", single_rooms: 1, double_rooms: 0,
      six_person_rooms: 0, mixed_dorm_beds: 0, female_dorm_beds: 0, breakfasts: 0
    } }
    booking = order.products.sole.productable
    original_price = order.total_cents

    patch admin_order_path(order), params: { order: { user_id: users(:two).id } }

    assert_response :unprocessable_entity
    assert_equal users(:admin), order.reload.user
    assert_equal original_price, order.total_cents
    assert_select "p", text: /This will empty the basket/
    token = css_select("input[name='owner_change_token']").first["value"]
    patch admin_order_path(order), params: { order: { user_id: users(:two).id }, owner_change_token: token }

    assert_redirected_to edit_admin_order_path(order)
    assert_equal users(:two), order.reload.user
    assert_not HostelBooking.exists?(booking.id)
    assert_equal 0, order.total_cents
  end

  test "adding a ticket for another user assigns the empty draft to that user" do
    participant = ticketless_participant
    order = users(:admin).orders.create!(status: "draft")

    post add_participant_admin_order_path(order), params: { participant_id: participant.id }

    assert_response :unprocessable_entity
    assert_equal users(:admin), order.reload.user
    token = css_select("input[name='owner_change_token']").first["value"]
    patch admin_order_path(order), params: { order: { user_id: participant.user_id }, participant_id: participant.id, owner_change_token: token }

    assert_redirected_to edit_admin_order_path(order)
    assert_equal participant.user, order.reload.user
    assert_equal participant, order.products.sole.productable.participant
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Shopping Basket for Order #{order.id}"
    assert_select "input[name='order[user_id]'][value='#{participant.user_id}']"
    assert_select "a", text: "#{participant.first_name} #{participant.last_name}"
  end

  test "the participant ownership dialog offers Change owner and Cancel returns to selection" do
    participant = ticketless_participant
    order = users(:admin).orders.create!(status: "draft")

    assert_no_difference ["Order.count", "ParticipantTicket.count", "Product.count"] do
      post add_participant_admin_order_path(order), params: { participant_id: participant.id }
      assert_response :unprocessable_entity
      assert_select "input[type='submit'][value='Change owner']"
      assert_select "button", text: "Keep owner", count: 0
      assert_select "input[name='keep_order_owner']", count: 0
      assert_select "a[href='#{new_participant_admin_order_path(order)}']", text: "Cancel"
      get new_participant_admin_order_path(order)
      assert_response :success
      assert_select "h1", text: "Add a participant ticket"
    end
    assert_equal users(:admin), order.reload.user
    assert_empty order.products
  end

  test "participant search excludes tickets already added after changing the Admin draft owner" do
    participant = ticketless_participant
    available_participant = ticketless_participant
    order = users(:admin).orders.create!(status: "draft")
    post add_participant_admin_order_path(order), params: { participant_id: participant.id }
    token = css_select("input[name='owner_change_token']").sole["value"]
    patch admin_order_path(order), params: {
      order: { user_id: participant.user_id }, participant_id: participant.id, owner_change_token: token
    }
    assert_redirected_to edit_admin_order_path(order)
    assert_equal participant.user, order.reload.user

    [nil, participant.first_name[0, 3]].each do |query|
      get participants_admin_order_path(order), params: { q: query }, as: :json

      assert_response :success
      participant_ids = response.parsed_body.map { |entry| entry.fetch("id") }
      assert_not_includes participant_ids, participant.id
      assert_includes participant_ids, available_participant.id
      assert_includes participant_ids, participants(:three).id
    end

    assert_no_difference ["Order.count", "Product.count", "ParticipantTicket.count"] do
      post add_participant_admin_order_path(order), params: { participant_id: participant.id }
    end
    assert_redirected_to new_participant_admin_order_path(order)
    assert_nil flash[:alert]
    assert_nil flash[:unpaid_order_ids]
    assert_match "already has a ticket in this shopping basket", flash[:notice]
  end

  test "Admin-owned participant search excludes newly registered basket participants" do
    order = users(:admin).orders.create!(status: "draft")
    participant = users(:admin).participants.create!(
      first_name: "Basket", last_name: "Player", email: users(:admin).email, country: "NL", club: "Club",
      age_group: "18-49", gender: "female", attendance_option: "weekend_only", image_use_consent: true
    )
    assert_equal order, participant.current_order

    get participants_admin_order_path(order), params: { q: "Bas" }, as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  test "a submitted Keep owner parameter cannot bypass the participant ownership confirmation" do
    participant = ticketless_participant
    order = users(:admin).orders.create!(status: "draft")

    assert_no_difference ["Order.count", "Product.count", "ParticipantTicket.count"] do
      post add_participant_admin_order_path(order), params: {
        participant_id: participant.id, keep_order_owner: "true", owner_change_token: order.owner_change_token(order.user)
      }
    end

    assert_response :unprocessable_entity
    assert_select "input[name='order[user_id]'][value='#{participant.user_id}']"
    assert_select "a[href='#{new_participant_admin_order_path(order)}']", text: "Cancel"
    assert_equal users(:admin), order.reload.user
    assert_equal users(:one), participant.reload.user
    assert_empty order.products
  end

  test "confirming a selected participant's owner cannot modify their existing draft" do
    participant = ticketless_participant
    booking = participant.user.hostel_bookings.create!(arrival_date: "2027-07-24", departure_date: "2027-07-25", single_rooms: 1)
    existing_draft = booking.order
    existing_total = existing_draft.total_cents
    order = users(:admin).orders.create!(status: "draft")

    post add_participant_admin_order_path(order), params: { participant_id: participant.id }
    assert_response :unprocessable_entity
    token = css_select("input[name='owner_change_token']").sole["value"]
    assert_no_difference ["Order.count", "Product.count", "ParticipantTicket.count"] do
      patch admin_order_path(order), params: {
        order: { user_id: participant.user_id }, participant_id: participant.id, owner_change_token: token
      }
    end

    assert_redirected_to edit_admin_order_path(order)
    assert_equal existing_draft.id, flash[:existing_draft_id]
    assert_equal booking, existing_draft.products.reload.sole.productable
    assert_equal existing_total, existing_draft.total_cents
    assert_equal users(:admin), order.reload.user
    assert_empty order.products
  end

  test "participant search supports prefix matches in the shared selection page" do
    order = users(:admin).orders.create!(status: "draft")

    get participants_admin_order_path(order), params: { q: "Car" }, as: :json
    assert_response :success
    assert_includes response.parsed_body.map { |entry| entry.fetch("id") }, participants(:three).id
    assert_operator response.parsed_body.size, :<=, 10

    get new_participant_admin_order_path(order)
    assert_response :success
    assert_select "input[role='combobox']"
    assert_select "input[name='participant_id'][type='hidden']"
    assert_select "a[href='#{new_admin_order_participant_path(order)}']", text: "Register a new Participant"
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
    assert_match(/Order owner/, flash[:alert])
    assert_equal users(:one), order.reload.user
    assert_equal 1, order.products.count
  end

  test "changing owner does not modify an existing draft of the target user" do
    order = users(:admin).orders.create!(status: "draft")
    other_draft = users(:two).orders.create!(status: "draft")

    patch admin_order_path(order), params: { order: { user_id: users(:two).id } }

    assert_redirected_to edit_admin_order_path(order)
    follow_redirect!
    assert_select "[role='alert'] a[href='#{admin_order_path(other_draft)}']", text: "Order ##{other_draft.id}"
    assert_equal users(:admin), order.reload.user
    assert_empty other_draft.products
  end

  test "a ticket for a different owner is rejected without changing either basket" do
    order = users(:two).orders.create!(status: "draft")
    assert_no_difference ["Product.count", "ParticipantTicket.count"] do
      post add_participant_admin_order_path(order), params: { participant_id: participants(:three).id }
    end
    assert_redirected_to edit_admin_order_path(order)
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
