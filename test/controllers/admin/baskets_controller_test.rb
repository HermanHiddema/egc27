require "test_helper"

class Admin::BasketsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin) }

  def registration_attributes
    { first_name: "New", last_name: "Player", gender: "female", age_group: "18-49", country: "NL",
      club: "Amsterdam", rank: 25, image_use_consent: "true", attendance_option: "all_events", participant_type: "player" }
  end

  test "new Order opens an empty shared basket without creating a draft" do
    assert_no_difference "Order.count" do
      get new_admin_order_path
    end
    assert_response :success
    assert_select "h1", text: "Shopping basket"
    assert_select "h2", text: "Participant tickets"
    assert_select "h2", text: "Hostel bookings"
    assert_select "input[name='order[user_id]'][value='#{users(:admin).id}']"
    assert_select "input[role='combobox']"
    assert_select "form[action='#{admin_orders_path}'] input[name='next_step'][value='participant']"
  end

  test "the add ticket action creates a draft as needed and opens shared participant selection" do
    assert_difference "Order.count", 1 do
      post admin_orders_path, params: { order: { user_id: users(:admin).id }, next_step: "participant" }
    end
    order = Order.last
    assert_redirected_to new_participant_admin_order_path(order)
    follow_redirect!
    assert_response :success
    assert_select "a[href='#{new_admin_order_participant_path(order)}']", text: "Register a new Participant"
    assert_select "form[action='#{add_participant_admin_order_path(order)}'] input[role='combobox']"
  end

  test "submitting an Admin Order does not create a replacement draft or block the next Order" do
    post admin_orders_path
    order = users(:admin).orders.drafts.sole
    post admin_order_participants_path(order), params: {
      registration_owner_id: order.user_id, participant: registration_attributes
    }
    assert_redirected_to edit_admin_order_path(order)

    assert_no_difference "Order.count" do
      patch submit_admin_order_path(order), params: { confirmed_total_cents: order.total_cents }
      assert_redirected_to admin_order_path(order)
      follow_redirect!
      assert_response :success
      get order_path, headers: { "X-Sec-Purpose" => "prefetch" }
      assert_response :success
      get admin_orders_path
      assert_response :success
      get new_admin_order_path
      assert_response :success
      assert_select "[role='alert']", count: 0
    end
    assert order.reload.submitted?
    assert_empty users(:admin).orders.drafts

    assert_difference "Order.count", 1 do
      post admin_orders_path, params: { next_step: "participant" }
    end
    assert_redirected_to new_participant_admin_order_path(users(:admin).orders.drafts.sole)
  end

  test "admin registration uses the selected owner and creates its ticket in the managed basket" do
    order = users(:two).orders.create!(status: "draft")
    get new_admin_order_participant_path(order)
    assert_response :success
    assert_select "input[name='participant[email]'][readonly][value='#{users(:two).email}']"

    assert_difference ["Participant.count", "ParticipantTicket.count", "Product.count"], 1 do
      assert_no_difference "Order.count" do
        post admin_order_participants_path(order), params: {
          registration_owner_id: order.user_id,
          participant: registration_attributes.merge(email: users(:admin).email, user_id: users(:admin).id)
        }
      end
    end
    assert_redirected_to edit_admin_order_path(order)
    participant = Participant.order(:id).last
    assert_equal users(:two), participant.user
    assert_equal users(:two).email, participant.email
    assert_equal order, participant.current_order
    assert_equal participant, order.products.sole.productable.participant
  end

  test "invalid admin registration returns the shared form without creating partial records" do
    order = users(:two).orders.create!(status: "draft")
    assert_no_difference ["Participant.count", "ParticipantTicket.count", "Product.count"] do
      post admin_order_participants_path(order), params: {
        registration_owner_id: order.user_id, participant: registration_attributes.merge(first_name: "")
      }
    end
    assert_response :unprocessable_entity
    assert_select "li", text: "First name can't be blank"
    assert_select "input[name='participant[email]'][readonly][value='#{order.user.email}']"
  end

  test "registration does not silently follow an owner changed after opening the form" do
    order = users(:two).orders.create!(status: "draft")
    assert_no_difference "Participant.count" do
      post admin_order_participants_path(order), params: {
        registration_owner_id: users(:admin).id, participant: registration_attributes
      }
    end
    assert_redirected_to edit_admin_order_path(order)
    assert_match(/owner changed/, flash[:alert])
  end

  test "owner changes preserve ticket registrations and require confirmation of the full basket" do
    order = users(:admin).orders.create!(status: "draft")
    post admin_order_participants_path(order), params: {
      registration_owner_id: order.user_id, participant: registration_attributes
    }
    participant = order.products.sole.productable.participant

    assert_no_difference ["ParticipantTicket.count", "Product.count"] do
      patch admin_order_path(order), params: { order: { user_id: users(:two).id } }
    end
    assert_response :unprocessable_entity
    assert_select "li", text: /New Player/
    assert_select "p", text: /Current total:/
    token = css_select("input[name='owner_change_token']").first["value"]

    assert_difference ["ParticipantTicket.count", "Product.count"], -1 do
      assert_no_difference "Participant.count" do
        patch admin_order_path(order), params: { order: { user_id: users(:two).id }, owner_change_token: token }
      end
    end
    assert_redirected_to edit_admin_order_path(order)
    assert_equal users(:two), order.reload.user
    assert_equal users(:admin), participant.reload.user
    assert_empty order.products
  end

  test "a confirmation token cannot authorize clearing products added after review" do
    order = users(:admin).orders.create!(status: "draft")
    post admin_order_participants_path(order), params: { registration_owner_id: order.user_id, participant: registration_attributes }
    patch admin_order_path(order), params: { order: { user_id: users(:two).id } }
    token = css_select("input[name='owner_change_token']").first["value"]
    post admin_order_participants_path(order), params: { registration_owner_id: order.user_id, participant: registration_attributes.merge(first_name: "Another") }

    assert_no_difference ["Product.count", "ParticipantTicket.count"] do
      patch admin_order_path(order), params: { order: { user_id: users(:two).id }, owner_change_token: token }
    end
    assert_response :unprocessable_entity
    assert_select "li", count: 2
    assert_equal users(:admin), order.reload.user
  end

  test "an Admin-owned basket can search other users and explicitly replace its tickets" do
    order = users(:admin).orders.create!(status: "draft")
    post admin_order_participants_path(order), params: { registration_owner_id: order.user_id, participant: registration_attributes }
    original_participant = order.products.sole.productable.participant
    other_participant = participants(:three).dup
    other_participant.uuid = SecureRandom.uuid
    other_participant.egd_pin = nil
    other_participant.first_name = "Other"
    other_participant.save!
    other_participant.current_order.destroy!
    other_participant.reload

    get participants_admin_order_path(order), params: { q: "Other" }, as: :json
    assert_includes response.parsed_body.map { |match| match.fetch("id") }, other_participant.id
    post add_participant_admin_order_path(order), params: { participant_id: other_participant.id }
    assert_response :unprocessable_entity
    assert_equal original_participant, order.products.reload.sole.productable.participant
    token = css_select("input[name='owner_change_token']").first["value"]

    patch admin_order_path(order), params: {
      order: { user_id: other_participant.user_id }, participant_id: other_participant.id, owner_change_token: token
    }
    assert_redirected_to edit_admin_order_path(order)
    assert_equal other_participant.user, order.reload.user
    assert_equal other_participant, order.products.sole.productable.participant
    assert_equal users(:admin), original_participant.reload.user
  end

  test "admin uses shared ticket editing and empty basket operations" do
    order = users(:two).orders.create!(status: "draft")
    post admin_order_participants_path(order), params: { registration_owner_id: order.user_id, participant: registration_attributes }
    product = order.products.sole
    get edit_admin_order_product_path(order, product)
    assert_response :success
    assert_select "form[action='#{admin_order_product_path(order, product)}']"
    patch admin_order_product_path(order, product), params: { participant: { attendance_option: "weekend_only" } }
    assert_redirected_to edit_admin_order_path(order)
    assert_equal "weekend_only", product.productable.participant.reload.attendance_option
    assert_equal product.productable.price_for, product.reload.price_cents

    assert_difference ["ParticipantTicket.count", "Product.count"], -1 do
      assert_no_difference "Participant.count" do
        delete empty_admin_order_path(order)
      end
    end
    assert_redirected_to edit_admin_order_path(order)
  end

  test "non-admins cannot use owner search, registration or ticket editing" do
    sign_out users(:admin)
    sign_in users(:one)
    order = orders(:three)
    get owners_admin_orders_path, params: { q: "Al" }, as: :json
    assert_redirected_to root_path
    get new_admin_order_participant_path(order)
    assert_redirected_to root_path
    assert_no_difference "Participant.count" do
      post admin_order_participants_path(order), params: { registration_owner_id: order.user_id, participant: registration_attributes }
    end
    assert_redirected_to root_path
    get edit_admin_order_product_path(order, order.products.sole)
    assert_redirected_to root_path
  end

  test "owner selection offers initial dropdown choices and saves on selection" do
    get new_admin_order_path
    assert_select "form[data-remote-select-auto-submit-value='true']" do
      assert_select "button[aria-haspopup='listbox']", text: /#{users(:admin).email}/
      assert_select "input[role='combobox'][value]", count: 0
      assert_select "input[type='submit']", count: 0
    end
    get owners_admin_orders_path, as: :json
    assert_response :success
    assert_operator response.parsed_body.size, :<=, 10
    assert_includes response.parsed_body.map { |owner| owner.fetch("id") }, users(:admin).id
  end

  test "selecting an unpaid ticket warns with a link while keeping the current draft" do
    order = users(:admin).orders.create!(status: "draft")
    unpaid_order = orders(:three)
    assert_no_difference ["Order.count", "Product.count", "ParticipantTicket.count"] do
      post add_participant_admin_order_path(order), params: { participant_id: participants(:three).id }
    end
    assert_redirected_to new_participant_admin_order_path(order)
    follow_redirect!
    assert_select "[role='alert']", text: /This participant already has a ticket in an order. Pay or cancel that order/ do
      assert_select "a[href='#{admin_order_path(unpaid_order, return_order_id: order.id)}']", text: "Order ##{unpaid_order.id}"
    end
    assert_select "a[href='#{edit_admin_order_path(order)}']", text: "Back to shopping basket"
    assert_empty order.products
    assert_equal users(:admin), order.reload.user
  end

  test "canceling a linked unpaid Order returns to participant selection in the original basket" do
    order = users(:one).orders.create!(status: "draft")
    post admin_order_participants_path(order), params: {
      registration_owner_id: order.user_id, participant: registration_attributes
    }
    original_products = order.products.pluck(:id)
    original_total = order.total_cents
    participant = participants(:three)
    unpaid_order = orders(:three)
    old_ticket = participant.participant_tickets.sole

    assert_no_difference ["Order.count", "Product.count", "ParticipantTicket.count"] do
      post add_participant_admin_order_path(order), params: { participant_id: participant.id }
      follow_redirect!
      unpaid_link = css_select("[role='alert'] a").sole["href"]
      get unpaid_link
      assert_response :success
      assert_select "a[href='#{new_participant_admin_order_path(order)}']", text: "Back to adding participants to Order ##{order.id}"
      assert_select "form[action='#{cancel_admin_order_path(unpaid_order)}']" do
        assert_select "input[type='hidden'][name='return_order_id'][value='#{order.id}']"
      end
      patch cancel_admin_order_path(unpaid_order), params: { return_order_id: order.id }
      assert_redirected_to new_participant_admin_order_path(order)
      follow_redirect!
      assert_response :success
      assert_select "h1", text: "Add a participant ticket"
    end
    assert unpaid_order.reload.cancelled?
    assert old_ticket.reload.invalidated_at
    assert_equal original_products, order.products.reload.pluck(:id)
    assert_equal original_total, order.total_cents

    assert_difference ["Product.count", "ParticipantTicket.count"], 1 do
      assert_no_difference "Order.count" do
        post add_participant_admin_order_path(order), params: { participant_id: participant.id }
      end
    end
    assert_redirected_to edit_admin_order_path(order)
    assert_equal order, participant.reload.draft_ticket.order
    assert_equal 2, order.products.reload.count
  end

  test "draft ownership conflicts explain the issue and link the conflicting Order in the same message" do
    users(:two).update!(full_name: "User Two")
    order = users(:admin).orders.create!(status: "draft")
    existing = users(:two).orders.create!(status: "draft")
    patch admin_order_path(order), params: { order: { user_id: users(:two).id } }
    assert_redirected_to edit_admin_order_path(order)
    follow_redirect!
    assert_select "[role='alert']", text: /User Two already has a draft order. This order needs to be completed before a new order in their name can be processed./ do
      assert_select "a[href='#{admin_order_path(existing)}']", text: "Order ##{existing.id}"
    end
    assert_select "h1", text: "Shopping Basket for Order #{order.id}"
    assert_equal users(:admin), order.reload.user
    assert_empty existing.products
  end

  test "the selected owner persists through registration submission payment and Order histories" do
    order = users(:admin).orders.create!(status: "draft")
    patch admin_order_path(order), params: { order: { user_id: users(:two).id } }
    assert_redirected_to edit_admin_order_path(order)
    assert_equal users(:two), order.reload.user
    post admin_order_participants_path(order), params: { registration_owner_id: users(:two).id, participant: registration_attributes }
    assert_redirected_to edit_admin_order_path(order)
    assert_equal users(:two), order.products.sole.productable.participant.user
    patch submit_admin_order_path(order), params: { confirmed_total_cents: order.total_cents }
    assert_redirected_to admin_order_path(order)
    post admin_order_payments_path(order), params: {
      confirmed_total_cents: order.total_cents,
      payment: { description: "Offline payment", payment_date: Date.current, payment_method: "cash" }
    }
    assert_redirected_to admin_order_path(order)
    assert_equal users(:two), order.payments.sole.order.user

    get submitted_orders_path
    assert_select "a[href='#{submitted_order_path(order)}']", count: 0
    sign_out users(:admin)
    sign_in users(:two)
    get submitted_orders_path
    assert_response :success
    assert_select "a[href='#{submitted_order_path(order)}']"
  end

  test "Admin draft deletion is available for empty drafts on the list details and basket" do
    order = users(:two).orders.create!(status: "draft")
    [admin_orders_path, admin_order_path(order), edit_admin_order_path(order)].each do |path|
      get path
      assert_response :success
      assert_select "form[action='#{discard_admin_order_path(order)}'][data-turbo-confirm]" do
        assert_select "button", text: "Delete draft Order"
        assert_select "input[name='_method'][value='delete']"
      end
    end
    assert_difference "Order.count", -1 do
      delete discard_admin_order_path(order)
    end
    assert_redirected_to admin_orders_path
    assert_not Order.exists?(order.id)
    assert_difference "Order.count", 1 do
      post admin_orders_path, params: { order: { user_id: users(:two).id } }
    end
    assert_redirected_to edit_admin_order_path(Order.last)
    assert_equal users(:two), Order.last.user
  end

  test "deleting a draft removes provisional products but keeps participants and financial history" do
    order = users(:two).orders.create!(status: "draft")
    post admin_order_participants_path(order), params: { registration_owner_id: order.user_id, participant: registration_attributes }
    participant = order.products.sole.productable.participant
    post admin_order_hostel_bookings_path(order), params: { hostel_booking: {
      arrival_date: "2027-07-24", departure_date: "2027-07-26", single_rooms: 1, double_rooms: 0,
      six_person_rooms: 0, mixed_dorm_beds: 0, female_dorm_beds: 0, breakfasts: 0
    } }
    assert_difference "Product.count", -2 do
      assert_difference ["ParticipantTicket.count", "HostelBooking.count", "Order.count"], -1 do
        assert_no_difference ["Participant.count", "Payment.count"] do
          delete discard_admin_order_path(order)
        end
      end
    end
    assert participant.reload.persisted?
    assert orders(:two).persisted?
  end

  test "draft deletion rejects submitted Orders and non-admin requests" do
    order = orders(:two)
    assert_no_difference ["Order.count", "Payment.count", "Product.count"] do
      delete discard_admin_order_path(order)
    end
    assert_redirected_to admin_order_path(order)
    sign_out users(:admin)
    sign_in users(:two)
    draft = users(:two).orders.create!(status: "draft")
    assert_no_difference "Order.count" do
      delete discard_admin_order_path(draft)
    end
    assert_redirected_to root_path
    assert draft.reload.persisted?
  end
end
