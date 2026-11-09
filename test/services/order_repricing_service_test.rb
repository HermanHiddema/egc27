require "test_helper"

class OrderRepricingServiceTest < ActiveSupport::TestCase
  test "reprices an eligible participant order and is idempotent" do
    participant = participants(:three)
    order = participant.order
    product = order.products.sole
    date = Date.new(2027, 2, 1)
    expected = participant.participant_ticket.price_for(date:)

    OrderRepricingService.call(order:, date:)
    updated_at = product.reload.updated_at
    OrderRepricingService.call(order:, date:)

    assert_equal expected, product.reload.price_cents
    assert_equal updated_at, product.updated_at
    assert_equal expected, order.reload.total_cents
  end

  test "does not reprice an order with a paid payment" do
    order = participants(:two).order
    product = order.products.sole
    old_price = product.price_cents

    OrderRepricingService.call(order:, date: Date.new(2027, 2, 1))

    assert_equal old_price, product.reload.price_cents
  end

  test "refunds and chargebacks leave the paid order closed and its price unchanged" do
    order = participants(:two).order
    product = order.products.sole
    payment = payments(:paid_payment)
    original_price = product.price_cents
    original_amount = payment.amount_cents

    [[:amount_refunded, "10.00"], [:amount_charged_back, "50.00"]].each do |field, amount|
      payment.sync_from_mollie!(OpenStruct.new(status: "paid", field => OpenStruct.new(value: amount)))
      OrderRepricingService.call(order:, date: Date.new(2027, 6, 1))

      assert order.closed?
      assert_equal "paid", payment.reload.status
      assert_equal original_price, product.reload.price_cents
      assert_equal original_amount, payment.amount_cents
    end
  end

  test "does not reprice hostel booking products" do
    booking = users(:one).hostel_bookings.create!(
      arrival_date: Date.new(2027, 7, 24),
      departure_date: Date.new(2027, 7, 27),
      double_rooms: 1
    )
    product = booking.order.products.sole
    old_price = product.price_cents

    OrderRepricingService.call(order: booking.order, date: Date.new(2027, 6, 1))

    assert_equal old_price, product.reload.price_cents
    assert_equal booking.amount_cents, product.price_cents
  end

  test "a pending Mollie attempt protects its original price through payment success" do
    participant = participants(:three)
    order = participant.order
    product = order.products.sole
    old_price = product.price_cents
    payment = Payment.create!(order:, amount_cents: old_price, description: "Pending attempt", status: "pending")

    OrderRepricingService.call(order:, date: Date.new(2027, 2, 1))
    payment.update!(status: "paid")
    OrderRepricingService.call(order:, date: Date.new(2027, 6, 1))

    assert_equal old_price, product.reload.price_cents
    assert_equal old_price, payment.reload.amount_cents
  end

  %w[failed expired canceled].each do |status|
    test "a #{status} Mollie attempt triggers repricing while preserving the attempt amount" do
      participant = participants(:three)
      order = participant.order
      product = order.products.sole
      old_price = product.price_cents
      payment = Payment.create!(order:, amount_cents: old_price, description: "Pending attempt", status: "pending")
      current_price = participant.participant_ticket.price_for(date: Date.new(2027, 2, 1))

      travel_to Date.new(2027, 2, 1) do
        payment.update!(status: status)
      end

      assert_equal current_price, product.reload.price_cents
      assert_equal old_price, payment.reload.amount_cents
      assert_equal current_price, Payment.build_for(participant).amount_cents
    end
  end

  test "participant ticket and hostel booking products store their prices at creation" do
    participant = participants(:three).dup
    participant.uuid = SecureRandom.uuid
    participant.egd_pin = nil
    participant.age_group = "12-17"
    participant.attendance_option = "weekend_only"
    participant.save!

    assert_equal participant.participant_ticket.price_for, participant.order.products.sole.price_cents

    booking = users(:one).hostel_bookings.create!(
      arrival_date: Date.new(2027, 7, 24),
      departure_date: Date.new(2027, 7, 25),
      mixed_dorm_beds: 1
    )
    assert_equal booking.amount_cents, booking.order.products.sole.price_cents
  end
end
