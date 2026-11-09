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

  test "an order requires exactly one supported product" do
    assert_not Order.new.valid?
    order = participants(:one).order
    order.products.build(productable: participants(:two).participant_ticket)
    assert_not order.valid?
    assert_not Product.new(order: order, productable: users(:one)).valid?
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
