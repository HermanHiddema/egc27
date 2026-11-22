require "test_helper"

class Admin::PaymentsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def create_ticketless_participant
    participant = participants(:three).dup
    participant.uuid = SecureRandom.uuid
    participant.egd_pin = nil
    participant.save!
    participant.current_order.destroy!
    participant.reload
  end

  def record_order_payment(order = orders(:three), attributes = {})
    get new_admin_order_payment_path(order)
    post admin_order_payments_path(order), params: {
      confirmed_total_cents: order.reload.total_cents,
      payment: { description: "Cash at the venue", payment_method: "cash", payment_date: "2026-10-15" }.merge(attributes)
    }
  end

  test "unauthenticated user is redirected to sign in" do
    get new_admin_order_payment_path(orders(:three))
    assert_redirected_to new_user_session_path
  end

  test "editor cannot record a payment" do
    sign_in users(:editor)
    assert_no_difference "Payment.count" do
      post admin_order_payments_path(orders(:three)), params: { payment: { description: "Cash", payment_method: "cash", payment_date: Date.current } }
    end
    assert_redirected_to root_path
  end

  test "admin can open the Order payment form with a fixed total" do
    sign_in users(:admin)
    get new_admin_order_payment_path(orders(:three))
    assert_response :success
    assert_select "form[action='#{admin_order_payments_path(orders(:three))}']"
    %w[cash bank_transfer pointofsale paypal].each do |method|
      assert_select "select[name='payment[payment_method]'] option[value='#{method}']"
    end
    assert_select "input[name='payment[amount_eur]']", count: 0
    assert_select "select[name='payment[status]']", count: 0
    assert_select "select[name='payment[payment_method]'] option[value='mollie']", count: 0
  end

  test "opening the basket for a participant without a ticket stays read-only" do
    sign_in users(:admin)
    create_ticketless_participant
    assert_no_difference ["Order.count", "Product.count", "ParticipantTicket.count"] do
      get new_admin_order_path
    end
    assert_response :success
    assert_select "h1", text: "Shopping basket"
  end

  test "admin can explicitly add a ticket before recording payment" do
    sign_in users(:admin)
    participant = create_ticketless_participant
    assert_difference ["Order.count", "Product.count", "ParticipantTicket.count"], 1 do
      post add_payment_admin_participant_path(participant)
    end
    assert_redirected_to edit_admin_order_path(participant.reload.current_order)
    assert participant.current_order.draft?
    assert_empty participant.current_order.payments
  end

  test "the participant shortcut requires draft review before payment" do
    sign_in users(:admin)
    participant = create_ticketless_participant
    assert_no_difference "Payment.count" do
      post add_payment_admin_participant_path(participant)
    end
    order = participant.reload.current_order
    assert_redirected_to edit_admin_order_path(order)
    get new_admin_order_payment_path(order)
    assert_response :success
    assert_select "a[href='#{edit_admin_order_path(order)}']", text: "Review Order"
    assert_select "form[action='#{admin_order_payments_path(order)}']", count: 0
  end

  test "admin can record a manual payment for the full Order" do
    sign_in users(:admin)
    order = orders(:three)
    assert_difference "order.payments.count", 1 do
      record_order_payment(order, description: "Congress pass paid in cash", reference: "Receipt 42")
    end
    assert_redirected_to admin_order_path(order)
    payment = order.payments.order(:created_at).last
    assert_equal order.total_cents, payment.amount_cents
    assert_equal "manual", payment.provider
    assert_equal "cash", payment.payment_method
    assert_equal "Receipt 42", payment.reference
    assert_equal Date.new(2026, 10, 15), payment.payment_date
    assert payment.paid?
    assert_nil payment.mollie_payment_id
  end

  test "recording a paid payment sends the payment confirmation email" do
    sign_in users(:admin)
    assert_emails 1 do
      record_order_payment(orders(:three), description: "Bank transfer", payment_method: "bank_transfer")
    end
  end

  test "recorded payments are always assigned the manual provider" do
    sign_in users(:admin)
    record_order_payment(orders(:three), provider: "mollie", mollie_payment_id: "tr_spoofed")
    payment = orders(:three).payments.order(:created_at).last
    assert_equal "manual", payment.provider
    assert_nil payment.mollie_payment_id
  end

  test "recorded payments are always paid" do
    sign_in users(:admin)
    record_order_payment(orders(:three), status: "open")
    assert orders(:three).payments.order(:created_at).last.paid?
  end

  test "admin cannot record a payment with an unsupported method" do
    sign_in users(:admin)
    assert_no_difference "Payment.count" do
      record_order_payment(orders(:three), payment_method: "ideal")
    end
    assert_response :unprocessable_entity
  end

  test "invalid payment re-renders the form" do
    sign_in users(:admin)
    assert_no_difference "Payment.count" do
      record_order_payment(orders(:three), description: "")
    end
    assert_response :unprocessable_entity
    assert_select "li", text: "Description can't be blank"
  end

  test "recorded payment makes the participant show as paid" do
    sign_in users(:admin)
    record_order_payment(orders(:three))
    assert_equal "paid", participants(:three).reload.status
  end

  test "admin cannot create a ticket Order for a visitor" do
    sign_in users(:admin)
    visitor = participants(:visitor_one)
    assert_no_difference ["Payment.count", "Order.count", "ParticipantTicket.count"] do
      post add_payment_admin_participant_path(visitor)
    end
    assert_redirected_to edit_admin_participant_path(visitor)
  end

  test "visitor edit page does not offer the payment shortcut" do
    sign_in users(:admin)
    visitor = participants(:visitor_one)
    get edit_admin_participant_path(visitor)
    assert_response :success
    assert_select "form[action='#{add_payment_admin_participant_path(visitor)}']", count: 0
  end

  test "admin is blocked when the Order has an open Mollie payment" do
    sign_in users(:admin)
    assert_no_difference "Payment.count" do
      record_order_payment(orders(:one))
    end
    assert_response :unprocessable_entity
    assert_select "li", text: /An active Payment already exists/
  end

  test "admin can record a manual payment when the existing Mollie payment expired" do
    sign_in users(:admin)
    payments(:open_payment).update!(status: "expired")
    assert_difference "Payment.count", 1 do
      record_order_payment(orders(:one))
    end
    assert_redirected_to admin_order_path(orders(:one))
    assert participants(:one).reload.paid?
  end

  test "a submitted amount cannot override the full Order total" do
    sign_in users(:admin)
    record_order_payment(orders(:three), amount_eur: "abc")
    assert_redirected_to admin_order_path(orders(:three))
    assert_equal orders(:three).total_cents, orders(:three).payments.order(:created_at).last.amount_cents
  end

  # edit / update
  test "admin can open the edit form for a manual payment" do
    sign_in users(:admin)
    payment = payments(:manual_payment)

    get edit_admin_participant_payment_path(payment.participant, payment)

    assert_response :success
    assert_select "form[action='#{admin_participant_payment_path(payment.participant, payment)}']"
    assert_select "input[name='payment[reference]'][value='#{payment.reference}']"
    assert_select "select[name='payment[status]']", count: 0
  end

  test "admin cannot change a manual payment to a partial amount" do
    sign_in users(:admin)
    payment = payments(:manual_payment)

    patch admin_participant_payment_path(payment.participant, payment), params: {
      payment: {
        amount_eur: "95.50",
        description: "EGC 2027 Congress Pass – corrected",
        payment_method: "cash",
        payment_date: "2026-10-15",
        status: "paid",
        reference: "Receipt 7"
      }
    }

    assert_response :unprocessable_entity
    payment.reload
    assert_equal 19_000, payment.amount_cents
    assert_equal "bank_transfer", payment.payment_method
    assert_equal "manual", payment.provider
    assert_equal 19_000, payment.participant.order.products.sole.reload.price_cents
  end

  test "record payment form prefills the payment date with today" do
    sign_in users(:admin)

    travel_to Time.zone.local(2026, 10, 20, 12) do
      get new_admin_order_payment_path(orders(:three))
    end

    assert_response :success
    assert_select "input[type='text'][name='payment[payment_date]'][value='20/10/2026'][placeholder='dd/mm/yyyy']"
    assert_select "button[aria-label='Choose payment date'][type='button']"
  end

  test "manual payments accept unambiguous European dates" do
    sign_in users(:admin)
    travel_to Time.zone.local(2026, 10, 20, 12) do
      assert_difference "Payment.count", 1 do
        record_order_payment(orders(:three), payment_date: "03/04/2026")
      end
    end

    assert_redirected_to admin_order_path(orders(:three))
    assert_equal Date.new(2026, 4, 3), orders(:three).payments.order(:id).last.payment_date
  end

  test "invalid and future European payment dates show errors and preserve the input" do
    sign_in users(:admin)
    travel_to Time.zone.local(2026, 10, 20, 12) do
      { "29/02/2027" => /must be a valid date in dd\/mm\/yyyy format/,
        "01/01/0000" => /must be a valid date in dd\/mm\/yyyy format/,
        "21/10/2026" => /cannot be in the future/ }.each do |date, error|
        assert_no_difference "Payment.count" do
          record_order_payment(orders(:three), payment_date: date)
        end
        assert_response :unprocessable_entity
        assert_select "li", text: error
        assert_select "li", text: "Payment date can't be blank", count: 0
        assert_select "input[name='payment[payment_date]'][value=?]", date
      end
    end
  end

  test "editing a manual payment accepts European dates and rejects impossible dates" do
    sign_in users(:admin)
    payment = payments(:manual_payment)
    attributes = { amount_eur: format("%.2f", payment.amount_cents / 100.0), description: payment.description,
      payment_method: "cash", payment_date: "03/04/2026" }
    patch admin_participant_payment_path(payment.participant, payment), params: { payment: attributes }
    assert_redirected_to admin_participants_path
    assert_equal Date.new(2026, 4, 3), payment.reload.payment_date

    patch admin_participant_payment_path(payment.participant, payment), params: { payment: attributes.merge(payment_date: "31/02/2026") }
    assert_response :unprocessable_entity
    assert_select "li", text: /must be a valid date in dd\/mm\/yyyy format/
    assert_select "input[name='payment[payment_date]'][value='31/02/2026']"
    assert_equal Date.new(2026, 4, 3), payment.reload.payment_date
  end

  test "admin cannot record a manual payment without a payment date" do
    sign_in users(:admin)
    assert_no_difference "Payment.count" do
      record_order_payment(orders(:three), payment_date: "")
    end
    assert_response :unprocessable_entity
  end

  test "admin cannot edit a mollie payment" do
    sign_in users(:admin)
    payment = payments(:paid_payment)

    get edit_admin_participant_payment_path(payment.participant, payment)

    assert_redirected_to admin_order_path(payment.order)
  end

  test "admin cannot update a mollie payment" do
    sign_in users(:admin)
    payment = payments(:paid_payment)

    patch admin_participant_payment_path(payment.participant, payment), params: {
      payment: { amount_eur: "1.00", description: "Hacked", payment_method: "cash", payment_date: "2026-10-15", status: "paid" }
    }

    assert_redirected_to admin_order_path(payment.order)
    assert_equal 5_000, payment.reload.amount_cents
  end

  test "editor cannot update a manual payment" do
    sign_in users(:editor)
    payment = payments(:manual_payment)

    patch admin_participant_payment_path(payment.participant, payment), params: {
      payment: { amount_eur: "1.00", description: "Hacked", payment_method: "cash", payment_date: "2026-10-15", status: "paid" }
    }

    assert_redirected_to root_path
    assert_equal 19_000, payment.reload.amount_cents
  end

  test "invalid update re-renders the edit form" do
    sign_in users(:admin)
    payment = payments(:manual_payment)

    patch admin_participant_payment_path(payment.participant, payment), params: {
      payment: { amount_eur: "0", description: "", payment_method: "cash", payment_date: "2026-10-15", status: "paid" }
    }

    assert_response :unprocessable_entity
    assert_equal 19_000, payment.reload.amount_cents
  end

  test "manual payment cannot be changed to open on update" do
    sign_in users(:admin)
    payment = payments(:manual_payment)

    patch admin_participant_payment_path(payment.participant, payment), params: {
      payment: { amount_eur: "190.00", description: payment.description, payment_method: "cash", payment_date: "2026-10-15", status: "open" }
    }

    assert_redirected_to admin_participants_path
    assert payment.reload.paid?
  end

  test "payments of another participant cannot be edited through a mismatched participant" do
    sign_in users(:admin)
    payment = payments(:manual_payment)

    get edit_admin_participant_payment_path(participants(:one), payment)

    assert_response :not_found
  end

  test "participant pages offer editing for manual payments only" do
    sign_in users(:admin)
    manual = payments(:manual_payment)
    get edit_admin_participant_path(manual.participant)
    assert_response :success
    assert_select "a[href='#{edit_admin_participant_payment_path(manual.participant, manual)}']", text: "Edit payment"
    mollie = payments(:paid_payment)
    get edit_admin_participant_path(mollie.participant)
    assert_response :success
    assert_select "a[href='#{edit_admin_participant_payment_path(mollie.participant, mollie)}']", count: 0
  end

  # index
  test "unauthenticated user is redirected to sign in from the payments overview" do
    get admin_payments_path
    assert_redirected_to new_user_session_path
  end

  test "editor cannot view the payments overview" do
    sign_in users(:editor)
    get admin_payments_path

    assert_redirected_to root_path
  end

  test "admin sees paid and open payments in the overview" do
    sign_in users(:admin)
    get admin_payments_path

    assert_response :success
    assert_select "td", text: payments(:paid_payment).description
    assert_select "td", text: payments(:open_payment).description
    assert_select "th", text: "Bookkeeping", count: 0
  end

  test "admin sees hostel booking payments in the overview" do
    sign_in users(:admin)
    booking = users(:one).hostel_bookings.create!(
      arrival_date: Date.new(2027, 7, 24),
      departure_date: Date.new(2027, 7, 26),
      double_rooms: 1
    )
    booking.order.submit!
    payment = Payment.build_for_hostel_booking(booking).tap do |hostel_payment|
      hostel_payment.status = "paid"
      hostel_payment.save!
    end

    get admin_payments_path

    assert_response :success
    assert_select "td", text: payment.description
    assert_select "td", text: payment.amount_formatted
  end

  test "payments overview sorts each supported column in both directions" do
    sign_in users(:admin)
    all_payments = Payment.includes(order: :user).to_a
    sort_values = {
      "id" => ->(payment) { payment.id },
      "order_id" => ->(payment) { payment.order_id },
      "amount" => ->(payment) { payment.amount_cents },
      "payer" => ->(payment) { payment.order.user.full_name.presence || payment.order.user.email },
      "date" => ->(payment) { payment.payment_date || payment.created_at.to_date }
    }

    sort_values.each do |sort, value|
      %w[asc desc].each do |direction|
        expected = all_payments.sort do |left, right|
          comparison = value.call(left) <=> value.call(right)
          comparison = left.created_at <=> right.created_at if comparison.zero? && sort == "date"
          comparison *= -1 if direction == "desc"
          comparison.zero? ? right.id <=> left.id : comparison
        end

        get admin_payments_path, params: { sort: sort, direction: direction }

        assert_response :success
        assert_select "tbody tr td:first-child a" do |links|
          assert_equal expected.map { |payment| "##{payment.id}" }, links.map(&:text), "#{sort} #{direction}"
        end
      end
    end
  end

  test "payments overview ignores SQL fragments in sorting parameters" do
    sign_in users(:admin)
    get admin_payments_path
    default_order = css_select("tbody tr td:first-child a").map(&:text)

    get admin_payments_path, params: { sort: "payments.id; DROP TABLE payments", direction: "asc; DROP TABLE users" }

    assert_response :success
    assert_select "tbody tr td:first-child a" do |links|
      assert_equal default_order, links.map(&:text)
    end
  end

  test "admin sees charged-back payments in the overview" do
    sign_in users(:admin)
    payment = payments(:paid_payment)
    payment.update!(amount_charged_back_cents: 5_000)

    get admin_payments_path

    assert_response :success
    assert_select "td", text: payment.description
    assert_select "span", text: "Charged back"
  end

test "admin can inspect Mollie and manual payments and navigate to related records" do
  sign_in users(:admin)

  [payments(:paid_payment), payments(:manual_payment)].each do |payment|
    get admin_payment_path(payment)
    assert_response :success
    assert_select "h1", text: "Payment ##{payment.id}"
    assert_select "dd", text: payment.amount_formatted
    assert_select "dd", text: payment.provider_label
    assert_select "dd", text: payment.payment_method_label
    assert_select "dd", text: payment.reference if payment.reference.present?
    assert_select "dd", text: payment.mollie_payment_id if payment.mollie_payment_id.present?
    assert_select "a[href='#{admin_order_path(payment.order)}']"
    assert_select "a[href='#{admin_user_path(payment.order.user)}']", text: payment.order.user.display_name
    assert_select "a[href='#{admin_payments_path}']"
    assert_select "h2", text: "Order products", count: 0
    assert_select "form", count: 0
  end
end

test "payment detail shows every recorded status and handles missing metadata" do
  sign_in users(:admin)
  payment = payments(:open_payment)
  Payment::STATUSES.each do |status|
    payment.update_columns(status: status, mollie_payment_id: nil, payment_method: nil, reference: nil, payment_date: nil)
    get admin_payment_path(payment)
    assert_response :success
    assert_select "dd", text: status.humanize
    assert_select "dd", text: "—", minimum: 3
  end
end

test "payment detail shows recorded refund and chargeback amounts including zero and unknown" do
  sign_in users(:admin)
  payment = payments(:paid_payment)
  [[0, 0, "€ 0.00", "€ 0.00"], [1250, 500, "€ 12.50", "€ 5.00"], [nil, nil, "Unknown", "Unknown"]].each do |refunded, charged_back, refund_label, chargeback_label|
    payment.update_columns(amount_refunded_cents: refunded, amount_charged_back_cents: charged_back)
    get admin_payment_path(payment)
    assert_response :success
    assert_select "div", text: /Refunded amount\s*#{Regexp.escape(refund_label)}/
    assert_select "div", text: /Chargeback amount\s*#{Regexp.escape(chargeback_label)}/
  end
end

test "payment links are available from the overview and order" do
  sign_in users(:admin)
  payment = payments(:paid_payment)
  get admin_payments_path
  assert_select "a[href='#{admin_payment_path(payment)}']"
  get admin_order_path(payment.order)
  assert_select "a[href='#{admin_payment_path(payment)}']"
end

test "payment detail requires an admin" do
  payment = payments(:paid_payment)
  get admin_payment_path(payment)
  assert_redirected_to new_user_session_path
  sign_in users(:editor)
  get admin_payment_path(payment)
  assert_redirected_to root_path
end

end
