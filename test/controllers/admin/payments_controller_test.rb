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
    assert_select "select[name='payment[payment_method]'] option[value='bank_transfer']"
    # The provider is always manual here, so it is not offered as a method.
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
    assert_equal "manual", payment.provider
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

  test "recorded payments are always assigned the manual provider" do
    sign_in users(:admin)
    participant = participants(:one)

    post admin_participant_payments_path(participant), params: {
      payment: {
        amount_eur: "190.00",
        description: "Cash",
        payment_method: "cash",
        status: "paid",
        provider: "mollie",
        mollie_payment_id: "tr_spoofed"
      }
    }

    payment = participant.payments.order(:created_at).last
    assert_equal "manual", payment.provider
    assert_nil payment.mollie_payment_id
  end

  test "admin cannot record a payment with an unsupported method" do
    sign_in users(:admin)

    assert_no_difference "Payment.count" do
      post admin_participant_payments_path(participants(:one)), params: {
        payment: { amount_eur: "190.00", description: "Fake Mollie", payment_method: "ideal", status: "paid" }
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

  # edit / update
  test "admin can open the edit form for a manual payment" do
    sign_in users(:admin)
    payment = payments(:manual_payment)

    get edit_admin_participant_payment_path(payment.participant, payment)

    assert_response :success
    assert_select "form[action='#{admin_participant_payment_path(payment.participant, payment)}']"
    assert_select "input[name='payment[reference]'][value='#{payment.reference}']"
  end

  test "admin can update a manual payment" do
    sign_in users(:admin)
    payment = payments(:manual_payment)

    patch admin_participant_payment_path(payment.participant, payment), params: {
      payment: {
        amount_eur: "95.50",
        description: "EGC 2027 Congress Pass – corrected",
        payment_method: "cash",
        status: "paid",
        reference: "Receipt 7"
      }
    }

    assert_redirected_to admin_participants_path
    payment.reload
    assert_equal 9_550, payment.amount_cents
    assert_equal "cash", payment.payment_method
    assert_equal "Receipt 7", payment.reference
    assert_equal "manual", payment.provider
  end

  test "admin cannot edit a mollie payment" do
    sign_in users(:admin)
    payment = payments(:paid_payment)

    get edit_admin_participant_payment_path(payment.participant, payment)

    assert_redirected_to new_admin_participant_payment_path(payment.participant)
  end

  test "admin cannot update a mollie payment" do
    sign_in users(:admin)
    payment = payments(:paid_payment)

    patch admin_participant_payment_path(payment.participant, payment), params: {
      payment: { amount_eur: "1.00", description: "Hacked", payment_method: "cash", status: "paid" }
    }

    assert_redirected_to new_admin_participant_payment_path(payment.participant)
    assert_equal 5_000, payment.reload.amount_cents
  end

  test "editor cannot update a manual payment" do
    sign_in users(:editor)
    payment = payments(:manual_payment)

    patch admin_participant_payment_path(payment.participant, payment), params: {
      payment: { amount_eur: "1.00", description: "Hacked", payment_method: "cash", status: "paid" }
    }

    assert_redirected_to root_path
    assert_equal 19_000, payment.reload.amount_cents
  end

  test "invalid update re-renders the edit form" do
    sign_in users(:admin)
    payment = payments(:manual_payment)

    patch admin_participant_payment_path(payment.participant, payment), params: {
      payment: { amount_eur: "0", description: "", payment_method: "cash", status: "paid" }
    }

    assert_response :unprocessable_entity
    assert_equal 19_000, payment.reload.amount_cents
  end

  test "payments of another participant cannot be edited through a mismatched participant" do
    sign_in users(:admin)
    payment = payments(:manual_payment)

    get edit_admin_participant_payment_path(participants(:one), payment)

    assert_response :not_found
  end

  test "existing payments are listed with an edit link for manual payments only" do
    sign_in users(:admin)
    manual = payments(:manual_payment)

    get new_admin_participant_payment_path(manual.participant)

    assert_response :success
    assert_select "a[href='#{edit_admin_participant_payment_path(manual.participant, manual)}']", text: "Edit"

    mollie = payments(:paid_payment)
    get new_admin_participant_payment_path(mollie.participant)

    assert_response :success
    assert_select "a[href='#{edit_admin_participant_payment_path(mollie.participant, mollie)}']", count: 0
  end
end
