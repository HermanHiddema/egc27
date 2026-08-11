require "test_helper"

class Admin::PaymentsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "unauthenticated user is redirected to sign in" do
    get new_admin_participant_payment_path(participants(:one))
    assert_redirected_to new_user_session_path
  end

  test "editor cannot record a payment" do
    sign_in users(:editor)

    assert_no_difference "Payment.count" do
      post admin_participant_payments_path(participants(:one)), params: {
        payment: { amount_eur: "190.00", description: "Cash at the venue", payment_method: "cash", status: "paid" }
      }
    end

    assert_redirected_to root_path
  end

  test "admin can open the record payment form" do
    sign_in users(:admin)
    get new_admin_participant_payment_path(participants(:one))

    assert_response :success
    assert_select "form[action='#{admin_participant_payments_path(participants(:one))}']"
    assert_select "select[name='payment[payment_method]'] option[value='cash']"
    assert_select "select[name='payment[payment_method]'] option[value='mollie']", count: 0
  end

  test "admin can record a manual payment" do
    sign_in users(:admin)
    participant = participants(:one)

    assert_difference "participant.payments.count", 1 do
      post admin_participant_payments_path(participant), params: {
        payment: {
          amount_eur: "123.45",
          description: "EGC 2027 Congress Pass – paid in cash",
          payment_method: "cash",
          status: "paid",
          reference: "Receipt 42"
        }
      }
    end

    assert_redirected_to admin_participants_path
    payment = participant.payments.order(:created_at).last
    assert_equal 12_345, payment.amount_cents
    assert_equal "cash", payment.payment_method
    assert_equal "Receipt 42", payment.reference
    assert payment.paid?
    assert_nil payment.mollie_payment_id
  end

  test "recording a paid payment sends the payment confirmation email" do
    sign_in users(:admin)

    assert_emails 1 do
      post admin_participant_payments_path(participants(:one)), params: {
        payment: {
          amount_eur: "190.00",
          description: "Bank transfer",
          payment_method: "bank_transfer",
          status: "paid"
        }
      }
    end
  end

  test "admin cannot record a payment with the mollie payment method" do
    sign_in users(:admin)

    assert_no_difference "Payment.count" do
      post admin_participant_payments_path(participants(:one)), params: {
        payment: { amount_eur: "190.00", description: "Fake Mollie", payment_method: "mollie", status: "paid" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "invalid payment re-renders the form" do
    sign_in users(:admin)

    assert_no_difference "Payment.count" do
      post admin_participant_payments_path(participants(:one)), params: {
        payment: { amount_eur: "0", description: "", payment_method: "cash", status: "paid" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "recorded payment makes the participant show as paid" do
    sign_in users(:admin)
    participant = participants(:one)

    post admin_participant_payments_path(participant), params: {
      payment: { amount_eur: "190.00", description: "Cash", payment_method: "cash", status: "paid" }
    }

    assert_equal "Paid", participant.reload.registration_status
  end
end
