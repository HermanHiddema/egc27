require "application_system_test_case"

class AdminBasketTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    Warden.test_mode!
    @participant = participants(:three).dup
    @participant.uuid = SecureRandom.uuid
    @participant.egd_pin = nil
    @participant.first_name = "Zeta"
    @participant.last_name = "Searcher"
    @participant.save!
    @participant.current_order.destroy!
    login_as users(:admin), scope: :user
  end

  teardown { Warden.test_reset! }

  test "participant autocomplete supports keyboard selection and confirms a different owner" do
    visit new_admin_order_path
    click_button "Add participant ticket"
    assert_text "Select an existing participant"
    click_button "Select participant"
    find("input[role='combobox']").set("Zeta")
    assert_selector "[role='option']", text: "Zeta Searcher"
    find("input[role='combobox']").send_keys(:arrow_down, :enter)
    click_button "Add ticket"
    assert_text "Change Order owner"
    assert_text "Zeta Searcher"
    click_button "Change owner"
    assert_text "Shopping Basket for Order"
    assert_text "Zeta Searcher"
    assert_equal @participant.user_id, @participant.reload.current_order.user_id
    assert_selector "a[aria-label='Edit participant ticket for Zeta Searcher']"
  end

  test "the shared owner autocomplete selects another user without an initial creation screen" do
    visit new_admin_order_path
    assert_text "Shopping basket"
    find("button[aria-haspopup='listbox']").click
    field = find("input[role='combobox']")
    field.set(users(:two).email[0, 3])
    assert_selector "[role='option']", text: users(:two).email
    find("[role='option']", text: users(:two).email).click
    assert_text "Shopping Basket for Order"
    assert_selector "input[name='order[user_id]'][value='#{users(:two).id}']", visible: :all
    assert_equal users(:two), Order.last.user
  end

  test "changing the owner of a populated basket renders confirmation and then saves the owner" do
    order = users(:admin).orders.create!(status: "draft")
    participant = @participant.dup
    participant.uuid = SecureRandom.uuid
    participant.user = users(:admin)
    participant.email = users(:admin).email
    participant.save!
    visit edit_admin_order_path(order)
    find("button[aria-haspopup='listbox']").click
    find("input[role='combobox']").set(users(:two).email[0, 4])
    find("[role='option']", text: users(:two).email).click
    assert_text "Change Order owner"
    assert_text "This will empty the basket"
    assert_equal users(:admin), order.reload.user
    assert_equal 1, order.products.count
    click_button "Change owner and empty basket"
    assert_text "Shopping Basket for Order #{order.id}"
    assert_equal users(:two), order.reload.user
    assert_empty order.products
    assert participant.reload.persisted?
  end
end
