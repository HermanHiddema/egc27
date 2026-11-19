require "application_system_test_case"

class AdminOrderCancellationTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    Warden.test_mode!
    login_as users(:admin), scope: :user
  end

  teardown { Warden.test_reset! }

  test "the confirmation can dismiss or cancel the Order from its details" do
    order = orders(:three)
    visit admin_order_path(order)

    click_button "Cancel order"
    within "dialog[open]" do
      assert_text "Cancel Order #{order.id} containing 1 Participant ticket? Participant registrations will be kept."
      click_button "Do not cancel"
    end
    assert_no_selector "dialog[open]"
    assert_not order.reload.cancelled?

    click_button "Cancel order"
    find("dialog[open] button", text: "Do not cancel").send_keys(:escape)
    assert_no_selector "dialog[open]"
    assert_not order.reload.cancelled?

    click_button "Cancel order"
    within("dialog[open]") { click_button "OK" }
    assert_text "Order #{order.id} was cancelled."
    assert order.reload.cancelled?
  end

  test "the Orders overview uses the same confirmation" do
    order = orders(:three)
    visit admin_orders_path
    within "form[action='#{cancel_admin_order_path(order)}']" do
      click_button "Cancel order"
    end
    within "dialog[open]" do
      assert_text "Cancel Order #{order.id} containing 1 Participant ticket? Participant registrations will be kept."
      click_button "OK"
    end
    assert_text "Order #{order.id} was cancelled."
    assert order.reload.cancelled?
  end
end
