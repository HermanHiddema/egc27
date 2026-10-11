require "test_helper"

class Admin::SettlementsControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user is redirected to sign in" do
    get admin_settlements_path
    assert_redirected_to new_user_session_path
  end

  test "editor cannot view settlements" do
    sign_in users(:editor)

    get admin_settlements_path

    assert_redirected_to root_path
  end

  test "editor cannot sync settlements" do
    sign_in users(:editor)

    post sync_admin_settlements_path

    assert_redirected_to root_path
  end

  test "admin sees the settlements with their totals" do
    sign_in users(:admin)
    settlements(:paid_out).update!(payments_complete: true)
    payments(:paid_payment).update!(settlement: settlements(:paid_out))

    get admin_settlements_path

    assert_response :success
    assert_select "a[href='#{admin_settlement_path(settlements(:paid_out))}']", text: settlements(:paid_out).reference
    assert_select "td", text: "Paid out"
    assert_select "td", text: "€ 50.00"
    assert_select "td", text: "€ 2.00"
    assert_select "td", text: "€ 48.00"
  end

  test "admin sees deductions for a complete settlement with no linked payments in the list" do
    sign_in users(:admin)
    settlements(:paid_out).update!(payments_complete: true)

    get admin_settlements_path

    assert_response :success
    assert_select "td", text: "-€ 48.00"
  end

  test "admin is told how to configure the organization token when it is missing" do
    sign_in users(:admin)

    with_organization_token(nil) do
      get admin_settlements_path
    end

    assert_response :success
    assert_select "code", text: "MOLLIE_ORGANIZATION_TOKEN"
    assert_select "form[action='#{sync_admin_settlements_path}']", count: 0
  end

  test "admin can sync settlements when the organization token is configured" do
    sign_in users(:admin)

    with_organization_token("access_test") do
      get admin_settlements_path
    end

    assert_select "form[action='#{sync_admin_settlements_path}']"
  end

  test "admin sees the payments paid out in a settlement" do
    sign_in users(:admin)
    payments(:paid_payment).update!(settlement: settlements(:paid_out))

    get admin_settlement_path(settlements(:paid_out))

    assert_response :success
    assert_select "dd", text: "bal_fixture1"
    assert_select "td", text: payments(:paid_payment).description
    assert_select "td", text: payments(:paid_payment).mollie_payment_id
    assert_select "td", text: payments(:manual_payment).description, count: 0
  end

  test "admin sees deductions for a complete settlement with no linked payments" do
    sign_in users(:admin)
    settlements(:paid_out).update!(payments_complete: true)

    get admin_settlement_path(settlements(:paid_out))

    assert_response :success
    assert_select "dd", text: "-€ 48.00"
    assert_select "p", text: "No payments known here were paid out in this settlement."
  end

  test "admin sees the breakdown, refunds and chargebacks of a settlement" do
    sign_in users(:admin)
    settlements(:paid_out).update!(
      periods: { "2026" => { "10" => {
        "revenue" => [{ "description" => "iDEAL", "method" => "ideal", "count" => 2,
                         "amount_gross" => { "value" => "60.00", "currency" => "EUR" } }],
        "costs" => [{ "description" => "iDEAL fees", "method" => "ideal", "count" => 2,
                       "amount_gross" => { "value" => "0.70", "currency" => "EUR" } }],
        "invoice_id" => "inv_test1"
      } } },
      payments_complete: true,
      other_payments: [{ "id" => "tr_other1", "description" => "Webshop order 12", "method" => "ideal", "status" => "paid",
                         "amount_cents" => 7_500, "created_at" => "2026-09-20T10:00:00+00:00" }]
    )
    settlements(:paid_out).refunds.create!(mollie_refund_id: "re_test1", payment: payments(:paid_payment),
                                           mollie_payment_id: payments(:paid_payment).mollie_payment_id, description: "Cancelled",
                                           amount_cents: 1_000, settlement_amount_cents: -1_000, mollie_created_at: Time.utc(2026, 10, 2, 10))
    settlements(:paid_out).chargebacks.create!(mollie_chargeback_id: "chb_test1", mollie_payment_id: "tr_unknown", amount_cents: 2_500,
                                               settlement_amount_cents: -2_500, mollie_created_at: Time.utc(2026, 10, 3, 10))

    get admin_settlement_path(settlements(:paid_out))

    assert_response :success
    assert_select "h3", text: "October 2026"
    assert_select "td", text: "iDEAL"
    assert_select "td", text: "iDEAL fees"
    assert_select "td", text: "€ 60.00"
    assert_select "td", text: "€ 0.70"
    assert_select "td", text: "re_test1"
    assert_select "td", text: "Cancelled"
    assert_select "td", text: "-€ 10.00"
    assert_select "td", text: /#{payments(:paid_payment).participant.first_name}/
    assert_select "td", text: "chb_test1"
    assert_select "td", text: "-€ 25.00"
    assert_select "h2", text: "Payments from other webshops"
    assert_select "td", text: "tr_other1"
    assert_select "td", text: "Webshop order 12"
    assert_select "dd", text: "€ 75.00"
    assert_select "dd", text: "€ 27.00"
  end

  test "admin is told when a settlement has no breakdown yet" do
    sign_in users(:admin)

    get admin_settlement_path(settlements(:paid_out))

    assert_response :success
    assert_select "p", text: "No breakdown of this settlement has been fetched from Mollie yet."
    assert_select "p", text: "No refunds were deducted from this settlement."
    assert_select "p", text: "No chargebacks were deducted from this settlement."
  end

  test "admin can resync a settlement when the organization token is configured" do
    sign_in users(:admin)

    with_organization_token("access_test") do
      get admin_settlement_path(settlements(:paid_out))
    end

    assert_select "form[action='#{resync_admin_settlement_path(settlements(:paid_out))}']"
  end

  test "admin cannot resync a settlement without an organization token" do
    sign_in users(:admin)

    with_organization_token(nil) do
      get admin_settlement_path(settlements(:paid_out))
    end

    assert_select "form[action='#{resync_admin_settlement_path(settlements(:paid_out))}']", count: 0
  end

  test "editor cannot resync a settlement" do
    sign_in users(:editor)

    post resync_admin_settlement_path(settlements(:paid_out))

    assert_redirected_to root_path
  end

  test "resync syncs the settlement and reports the result" do
    sign_in users(:admin)
    requested = []

    with_sync_one(->(id) { requested << id; 3 }) do
      post resync_admin_settlement_path(settlements(:paid_out))
    end

    assert_equal [settlements(:paid_out).mollie_settlement_id], requested
    assert_redirected_to admin_settlement_path(settlements(:paid_out))
    assert_equal "Synced settlement with Mollie; 3 payments linked.", flash[:notice]
  end

  test "resync reports a skipped settlement" do
    sign_in users(:admin)

    with_sync_one(->(_id) { nil }) do
      post resync_admin_settlement_path(settlements(:paid_out))
    end

    assert_redirected_to admin_settlement_path(settlements(:paid_out))
    assert_equal "Settlement could not be synced: Mollie reported an unknown status.", flash[:alert]
  end

  test "resync reports a missing organization token" do
    sign_in users(:admin)

    with_sync_one(->(_id) { raise MollieSettlementSync::NotConfigured, "No Mollie organization access token is configured." }) do
      post resync_admin_settlement_path(settlements(:paid_out))
    end

    assert_redirected_to admin_settlement_path(settlements(:paid_out))
    assert_equal "No Mollie organization access token is configured.", flash[:alert]
  end

  test "resync reports Mollie errors" do
    sign_in users(:admin)

    with_sync_one(->(_id) { raise Mollie::Exception, "boom" }) do
      post resync_admin_settlement_path(settlements(:paid_out))
    end

    assert_redirected_to admin_settlement_path(settlements(:paid_out))
    assert_equal "Settlement could not be synced with Mollie: boom", flash[:alert]
  end

  test "payments overview links to the settlement of a payment" do
    sign_in users(:admin)
    payments(:paid_payment).update!(settlement: settlements(:paid_out))

    get admin_payments_path

    assert_response :success
    assert_select "a[href='#{admin_settlement_path(settlements(:paid_out))}']", text: settlements(:paid_out).reference
  end

  test "sync reports the result" do
    sign_in users(:admin)
    result = MollieSettlementSync::Result.new(settlements_count: 2, payments_count: 1)

    with_sync(-> { result }) do
      post sync_admin_settlements_path
    end

    assert_redirected_to admin_settlements_path
    assert_equal "Synced 2 settlements with Mollie; 1 payment linked.", flash[:notice]
  end

  test "sync reports a missing organization token" do
    sign_in users(:admin)

    with_sync(-> { raise MollieSettlementSync::NotConfigured, "No Mollie organization access token is configured." }) do
      post sync_admin_settlements_path
    end

    assert_redirected_to admin_settlements_path
    assert_equal "No Mollie organization access token is configured.", flash[:alert]
  end

  test "sync reports Mollie errors" do
    sign_in users(:admin)

    with_sync(-> { raise Mollie::Exception, "boom" }) do
      post sync_admin_settlements_path
    end

    assert_redirected_to admin_settlements_path
    assert_equal "Settlements could not be synced with Mollie: boom", flash[:alert]
  end

  private

  def with_sync(stub)
    original = MollieSettlementSync.instance_method(:call)
    MollieSettlementSync.define_method(:call) { stub.call }
    yield
  ensure
    MollieSettlementSync.define_method(:call, original)
  end

  def with_sync_one(stub)
    original = MollieSettlementSync.instance_method(:sync_one)
    MollieSettlementSync.define_method(:sync_one) { |id| stub.call(id) }
    yield
  ensure
    MollieSettlementSync.define_method(:sync_one, original)
  end

  def with_organization_token(token)
    original = MollieSettlementSync.method(:organization_token)
    MollieSettlementSync.define_singleton_method(:organization_token) { token }
    yield
  ensure
    MollieSettlementSync.define_singleton_method(:organization_token, &original)
  end
end
