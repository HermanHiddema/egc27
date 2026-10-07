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
    assert_select "td", text: payments(:paid_payment).description
    assert_select "td", text: payments(:paid_payment).mollie_payment_id
    assert_select "td", text: payments(:manual_payment).description, count: 0
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

  def with_organization_token(token)
    original = MollieSettlementSync.method(:organization_token)
    MollieSettlementSync.define_singleton_method(:organization_token) { token }
    yield
  ensure
    MollieSettlementSync.define_singleton_method(:organization_token, &original)
  end
end
