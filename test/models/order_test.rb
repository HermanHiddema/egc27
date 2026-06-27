require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "valid order with required attributes" do
    order = Order.new(user: users(:one), description: "Item", amount_cents: 1000, status: "cart")

    assert order.valid?
  end

  test "requires a description" do
    order = Order.new(user: users(:one), amount_cents: 1000, status: "cart")

    assert_not order.valid?
    assert_includes order.errors[:description], "can't be blank"
  end

  test "requires a positive integer amount" do
    order = Order.new(user: users(:one), description: "Item", amount_cents: 0, status: "cart")

    assert_not order.valid?
    assert_includes order.errors[:amount_cents], "must be greater than 0"
  end

  test "rejects unknown statuses" do
    order = Order.new(user: users(:one), description: "Item", amount_cents: 1000, status: "bogus")

    assert_not order.valid?
    assert_includes order.errors[:status], "is not included in the list"
  end

  test "orderable is optional" do
    order = Order.new(user: users(:one), description: "Item", amount_cents: 1000, status: "cart")

    assert order.valid?
  end

  test "unpaid scope excludes paid orders" do
    assert_includes Order.unpaid, orders(:cart_pass)
    assert_not_includes Order.unpaid, orders(:paid_order)
  end

  test "paid scope only returns paid orders" do
    assert_includes Order.paid, orders(:paid_order)
    assert_not_includes Order.paid, orders(:cart_pass)
  end

  test "amount helpers format euros" do
    order = orders(:cart_pass)

    assert_in_delta 190.0, order.amount_eur
    assert_equal "€ 190.00", order.amount_formatted
  end

  test "paid? reflects status" do
    assert orders(:paid_order).paid?
    assert_not orders(:cart_pass).paid?
  end

  test "assigns a unique order number on create" do
    order = Order.create!(user: users(:one), description: "Item", amount_cents: 1000, status: "cart")

    assert_match(/\AEGC-\d{4}-\d{6}\z/, order.order_number)
  end

  test "order number is not overwritten when provided" do
    order = Order.create!(user: users(:one), order_number: "EGC-2027-999999", description: "Item", amount_cents: 1000, status: "cart")

    assert_equal "EGC-2027-999999", order.order_number
  end

  test "order number must be unique" do
    duplicate = Order.new(user: users(:one), order_number: orders(:cart_pass).order_number, description: "Item", amount_cents: 1000, status: "cart")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:order_number], "has already been taken"
  end
end
