require "test_helper"
require "ostruct"

class CartControllerTest < ActionDispatch::IntegrationTest
  # show
  test "show requires authentication" do
    get cart_path

    assert_redirected_to new_user_session_path
  end

  test "show lists the current user's unpaid orders" do
    sign_in users(:one)

    get cart_path

    assert_response :success
    assert_match orders(:cart_pass).description, response.body
    assert_match orders(:cart_tshirt).description, response.body
    assert_no_match orders(:paid_order).description, response.body
    assert_no_match orders(:other_user_order).description, response.body
  end

  # checkout
  test "checkout redirects back when nothing is selected" do
    sign_in users(:one)

    post checkout_cart_path, params: { order_ids: [] }

    assert_redirected_to cart_path
    assert_equal "Select at least one item to pay.", flash[:alert]
  end

  test "checkout ignores orders that do not belong to the user" do
    sign_in users(:one)

    post checkout_cart_path, params: { order_ids: [orders(:other_user_order).id] }

    assert_redirected_to cart_path
    assert_equal "cart", orders(:other_user_order).reload.status
  end

  test "checkout creates one mollie payment for the selected orders" do
    sign_in users(:one)
    pass = orders(:cart_pass)
    tshirt = orders(:cart_tshirt)
    captured = {}
    mollie_stub = OpenStruct.new(id: "tr_cart123", checkout_url: "https://example.test/mollie-checkout")

    original = Mollie::Payment.method(:create)
    Mollie::Payment.define_singleton_method(:create) do |params|
      captured.merge!(params)
      mollie_stub
    end

    post checkout_cart_path, params: { order_ids: [pass.id, tshirt.id] }

    assert_redirected_to "https://example.test/mollie-checkout"
    assert_equal "215.00", captured[:amount][:value]
    assert_equal "tr_cart123", pass.reload.mollie_payment_id
    assert_equal "tr_cart123", tshirt.reload.mollie_payment_id
    assert_equal pass.checkout_reference, tshirt.checkout_reference
    assert_equal "pending", pass.status
  ensure
    Mollie::Payment.define_singleton_method(:create, original)
  end

  test "checkout returns items to the cart when mollie fails" do
    sign_in users(:one)
    pass = orders(:cart_pass)

    original = Mollie::Payment.method(:create)
    Mollie::Payment.define_singleton_method(:create) { |_params| raise Mollie::Exception, "boom" }

    post checkout_cart_path, params: { order_ids: [pass.id] }

    assert_redirected_to cart_path
    assert_match "Payment could not be started: boom", flash[:alert]
    pass.reload
    assert_equal "cart", pass.status
    assert_nil pass.checkout_reference
    assert_nil pass.mollie_payment_id
  ensure
    Mollie::Payment.define_singleton_method(:create, original)
  end

  # success
  test "success renders without a reference" do
    get success_cart_path

    assert_response :success
  end

  test "success syncs orders for the checkout reference" do
    pass = orders(:cart_pass)
    pass.update!(status: "pending", mollie_payment_id: "tr_sync1", checkout_reference: "ref-1")
    mollie_stub = OpenStruct.new(id: "tr_sync1", status: "paid")

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    get success_cart_path(reference: "ref-1")

    assert_response :success
    assert_match "Payment Successful", response.body
    assert_equal "paid", pass.reload.status
    assert_not_nil pass.paid_at
  ensure
    Mollie::Payment.define_singleton_method(:get, original)
  end

  # webhook
  test "webhook updates orders sharing the mollie payment id" do
    pass = orders(:cart_pass)
    tshirt = orders(:cart_tshirt)
    [pass, tshirt].each { |o| o.update!(status: "pending", checkout_reference: "ref-2") }
    pass.update_column(:mollie_payment_id, "tr_hook1")
    tshirt.update_column(:mollie_payment_id, "tr_hook1")
    mollie_stub = OpenStruct.new(id: "tr_hook1", status: "paid")

    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| mollie_stub }

    post webhook_cart_path, params: { id: "tr_hook1" }

    assert_response :ok
    assert_equal "paid", pass.reload.status
    assert_equal "paid", tshirt.reload.status
  ensure
    Mollie::Payment.define_singleton_method(:get, original)
  end

  test "webhook returns ok on unknown mollie id" do
    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |_id| raise Mollie::Exception, "not found" }

    post webhook_cart_path, params: { id: "tr_unknown" }

    assert_response :ok
  ensure
    Mollie::Payment.define_singleton_method(:get, original)
  end
end
