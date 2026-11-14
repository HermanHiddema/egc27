require "test_helper"

# == Schema Information
#
# Table name: orders
#
#  id           :bigint           not null, primary key
#  cancelled_at :datetime
#  status       :string           default("submitted"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_orders_on_user_id          (user_id)
#  index_orders_one_draft_per_user  (user_id) UNIQUE WHERE ((status)::text = 'draft'::text)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class OrderTest < ActiveSupport::TestCase
  test "registration stores admission on a ticket in the user's draft order" do
    participant = participants(:three).dup
    participant.egd_pin = nil
    participant.uuid = SecureRandom.uuid
    participant.attendance_option = "weekend_only"
    participant.save!

    ticket = participant.reload.participant_ticket
    assert_equal [false, true, false], [participant.first_week, participant.weekend, participant.second_week]
    assert_equal "weekend_only", participant.attendance_option
    assert_equal ticket, participant.order.products.find_by!(productable: ticket).productable
    assert participant.order.draft?
    assert_not ParticipantTicket.column_names.include?("first_week")
  end

  test "a booking and a ticket each have their own order" do
    booking = users(:one).hostel_bookings.create!(arrival_date: Date.new(2027, 7, 24), departure_date: Date.new(2027, 7, 27), double_rooms: 1)
    assert_equal booking, booking.order.products.sole.productable
    assert_not_equal participants(:one).order, booking.order
    assert_empty booking.order.payments
  end

  test "an order accepts multiple products and rejects unsupported product types" do
    assert_not Order.new.valid?
    participant = participants(:three).dup
    participant.uuid = SecureRandom.uuid
    participant.egd_pin = nil
    participant.save!
    order = participant.order
    second = participants(:one).dup
    second.uuid = SecureRandom.uuid
    second.egd_pin = nil
    second.user = participant.user
    second.save!
    assert_equal 2, order.products.count
    assert_not Product.new(order:, productable: users(:one)).valid?
  end

  test "a user reuses one draft and may have multiple submitted orders" do
    user = users(:one)
    draft = user.draft_order!
    assert_equal draft, user.draft_order!
    assert_equal 1, user.orders.drafts.count
    assert_equal 2, user.orders.submitted.count
    assert_raises(ActiveRecord::RecordInvalid) do
      user.orders.create!(status: "draft")
    end
  end

  test "a submitted order can only be changed through submission and a payment must cover the whole amount" do
    order = participants(:one).order
    assert_raises(ActiveRecord::RecordInvalid) { order.update!(status: "draft") }

    payment = order.payments.build(amount_cents: order.total_cents - 1, description: "Partial", status: "open")
    assert_not payment.valid?
    assert_includes payment.errors[:amount_cents], "must equal the full order amount"
  end

  test "checkout submits a mixed ticket and hostel order for its full stored amount" do
    user = users(:one)
    booking = user.hostel_bookings.create!(
      arrival_date: Date.new(2027, 7, 24), departure_date: Date.new(2027, 7, 25), mixed_dorm_beds: 1
    )
    participant = user.participants.create!(
      first_name: "New", last_name: "Player", email: user.email, country: "NL", club: "Club",
      age_group: "18-49", gender: "prefer_not_to_say", attendance_option: "weekend_only", image_use_consent: false
    )
    order = participant.order
    assert_equal 2, order.products.count
    total = order.products.sum(:price_cents)

    order.submit!

    assert order.submitted?
    assert_equal total, order.total_cents
    assert_equal user, order.user
    assert_not order.products.build(productable: participant.participant_ticket).valid?
    assert_raises(ActiveRecord::RecordNotDestroyed) { order.products.first.destroy! }
  end

  test "payment attempts for the same registration belong to the same order" do
    participant = participants(:one)
    payment = participant.order.payments.create!(status: "failed", amount_cents: participant.order.total_cents, description: "Attempt")
    assert_equal participant.order, payment.order
    assert_equal participant, payment.participant
    assert_includes participant.payments.reload, payment
  end

  test "order total is the sum of stored product prices" do
    order = participants(:one).order
    product = order.products.sole
    product.update_column(:price_cents, 20_345)

    assert_equal 20_345, order.reload.total_cents
    assert_equal order.total_cents, order.amount_cents
  end

  test "display totals use preloaded products without weakening the persisted total" do
    order = Order.includes(:products).find(orders(:three).id)
    original_total = order.products.sum(&:price_cents)

    assert_no_queries { assert_equal original_total, order.display_total_cents }

    updated_total = original_total + 100
    Product.where(order_id: order.id).update_all(price_cents: updated_total)
    assert_equal updated_total, order.total_cents
  end

  test "preloaded payments supply the displayed order status and action without queries" do
    order = Order.includes(:payments).find(orders(:one).id)

    assert_no_queries do
      assert_equal :resume, order.payment_action
      assert_not order.cancellable?
      assert_equal "Payment open", ApplicationController.helpers.order_payment_status(order)
    end
  end

  test "canceling an unpaid order after unsuccessful attempts preserves history and allows a replacement ticket" do
    order = orders(:three)
    ticket = participant_tickets(:three)
    payment = order.payments.create!(status: "failed", amount_cents: order.total_cents, description: "Failed attempt")

    order.cancel!

    assert order.reload.cancelled?
    assert ticket.reload.invalidated_at
    assert_equal payment, order.payments.reload.sole

    replacement = participants(:three).add_ticket_to_draft_order!
    assert_not_equal ticket, replacement
    assert replacement.order.draft?
  end

  test "paid and in-progress orders cannot be cancelled" do
    [orders(:one), orders(:two)].each do |order|
      assert_raises(ActiveRecord::RecordInvalid) { order.cancel! }
      assert_not order.reload.cancelled?
    end

    in_progress_order = orders(:three)
    in_progress_order.payments.create!(
      status: "pending", amount_cents: in_progress_order.total_cents, description: "Pending attempt"
    )
    assert_raises(ActiveRecord::RecordInvalid) { in_progress_order.cancel! }
    assert_not in_progress_order.reload.cancelled?
  end

  test "removing a draft registration preserves the user's persistent draft order" do
    participant = participants(:three).dup
    participant.egd_pin = nil
    participant.uuid = SecureRandom.uuid
    participant.save!
    order = participant.order

    participant.destroy!
    assert Order.exists?(order.id)
    assert order.reload.draft?
    assert_empty order.products
  end
end
