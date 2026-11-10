require "test_helper"

# == Schema Information
#
# Table name: orders
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class OrderTest < ActiveSupport::TestCase
  test "registration stores admission on a ticket with a single product and order" do
    participant = participants(:three).dup
    participant.egd_pin = nil
    participant.uuid = SecureRandom.uuid
    participant.attendance_option = "weekend_only"
    participant.save!

    ticket = participant.reload.participant_ticket
    assert_equal [false, true, false], [participant.first_week, participant.weekend, participant.second_week]
    assert_equal "weekend_only", participant.attendance_option
    assert_equal ticket, participant.order.products.sole.productable
    assert_not ParticipantTicket.column_names.include?("first_week")
  end

  test "a booking and a ticket each have their own order" do
    booking = users(:one).hostel_bookings.create!(arrival_date: Date.new(2027, 7, 24), departure_date: Date.new(2027, 7, 27), double_rooms: 1)
    assert_equal booking, booking.order.products.sole.productable
    assert_not_equal participants(:one).order, booking.order
    assert_empty booking.order.payments
  end

  test "an order requires at least one supported product" do
    assert_not Order.new.valid?
    assert_not Product.new(order: participants(:one).order, productable: users(:one)).valid?
  end

  test "an order is limited to one product" do
    participant = duplicate_ticket_participant
    another_participant = duplicate_ticket_participant
    order = participant.order
    another_product = another_participant.order.products.sole

    assert_not another_product.update(order:)

    assert_equal 1, order.reload.products.count
    assert_equal 1, another_participant.order.reload.products.count
  end

  test "an order without payments is unpaid" do
    assert_not fresh_order.paid?
  end

  test "paid state uses preloaded payments and product prices without queries" do
    paid_order = Order.includes(:payments, products: :productable).find(orders(:two).id)
    unpaid_order = Order.includes(:payments, products: :productable).find(orders(:one).id)
    expected_payment = payments(:paid_payment)

    assert_no_queries do
      assert_equal expected_payment, paid_order.successful_payment
      assert paid_order.paid?
      assert_nil unpaid_order.successful_payment
      assert_not unpaid_order.paid?
    end
  end

  test "failed and canceled attempts do not pay an order" do
    order = fresh_order
    order.payments.create!(status: "failed", amount_cents: order.amount_cents, description: "Failed attempt")
    assert_not order.reload.paid?

    order.payments.create!(status: "canceled", amount_cents: order.amount_cents, description: "Canceled attempt")
    assert_not order.reload.paid?
  end

  test "a failed attempt followed by a successful payment pays the order" do
    order = fresh_order
    order.payments.create!(status: "failed", amount_cents: order.amount_cents, description: "Failed attempt")
    order.payments.create!(status: "paid", amount_cents: order.amount_cents, description: "Successful attempt")

    assert order.reload.paid?
  end

  test "a canceled attempt followed by a successful payment pays the order" do
    order = fresh_order
    order.payments.create!(status: "canceled", amount_cents: order.amount_cents, description: "Canceled attempt")
    order.payments.create!(status: "paid", amount_cents: order.amount_cents, description: "Successful attempt")

    assert order.reload.paid?
  end

  test "multiple failed and canceled attempts can precede the successful payment" do
    order = fresh_order
    %w[failed canceled expired failed canceled].each do |status|
      order.payments.create!(status: status, amount_cents: order.amount_cents, description: "#{status} attempt")
      assert_not order.reload.paid?
    end
    order.payments.create!(status: "paid", amount_cents: order.amount_cents, description: "Successful attempt")

    assert order.reload.paid?
  end

  test "manual full-order payment needs no Mollie reference" do
    order = participants(:one).order
    payment = order.payments.create!(
      provider: "manual", payment_method: "cash", payment_date: Date.current,
      status: "paid", amount_cents: order.amount_cents, description: "Cash payment"
    )

    assert_nil payment.mollie_payment_id
    assert order.reload.paid?
  end

  private

  def duplicate_ticket_participant
    participant = participants(:three).dup
    participant.egd_pin = nil
    participant.uuid = SecureRandom.uuid
    participant.save!
    participant
  end

  def fresh_order
    duplicate_ticket_participant.order
  end

  test "payment attempts for the same registration belong to the same order" do
    participant = participants(:one)
    payment = participant.order.payments.create!(status: "failed", amount_cents: 1000, description: "Attempt")
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
  test "removing a new unpaid registration also removes its product and order" do
    participant = participants(:three).dup
    participant.egd_pin = nil
    participant.uuid = SecureRandom.uuid
    participant.save!
    order_id = participant.order.id

    participant.destroy!
    assert_not Order.exists?(order_id)
  end
end
