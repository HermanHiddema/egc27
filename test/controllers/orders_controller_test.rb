require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  test "an owner can add an existing participant's ticket once and remove it without deleting the participant" do
    sign_in users(:one)

    post add_participant_order_path, params: { participant_id: participants(:three).uuid }
    assert_redirected_to order_path
    order = users(:one).orders.drafts.sole
    ticket = order.products.sole.productable

    assert_no_difference("Product.count") do
      post add_participant_order_path, params: { participant_id: participants(:three).uuid }
    end
    assert_redirected_to order_path

    delete remove_product_order_path(product_id: ticket.product.id)
    assert_redirected_to order_path
    assert Participant.exists?(participants(:three).id)
    assert_not ParticipantTicket.exists?(ticket.id)
    assert_empty order.reload.products
  end

  test "a user cannot add another user's participant" do
    sign_in users(:one)

    assert_no_difference("Product.count") do
      post add_participant_order_path, params: { participant_id: participants(:two).uuid }
    end
    assert_response :not_found
  end

  test "an empty draft cannot be submitted" do
    sign_in users(:one)

    post submit_order_path

    assert_redirected_to order_path
    assert users(:one).orders.drafts.exists?
    assert_empty users(:one).orders.drafts.sole.payments
  end
end
