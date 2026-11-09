require "test_helper"
require Rails.root.join("db/migrate/20261109120000_store_product_prices").to_s

class StoreProductPricesTest < ActiveSupport::TestCase
  parallelize(workers: 1)

  setup do
    @booking = HostelBooking.create!(
      user: users(:one),
      arrival_date: Date.new(2027, 7, 24),
      departure_date: Date.new(2027, 7, 25),
      mixed_dorm_beds: 1
    )
    @hostel_price_cents = @booking.amount_cents
    @migration = StoreProductPrices.new
    @migration.migrate(:down)
    ActiveRecord::Base.connection.clear_cache!
  end

  teardown do
    ActiveRecord::Base.connection.clear_cache!
    Product.reset_column_information
    ParticipantTicket.reset_column_information
    Payment.reset_column_information
  end

  test "prefers the amount of an active Mollie attempt and leaves payment amounts unchanged" do
    payment = payments(:open_payment)
    legacy_payment.update_all(amount_cents: 22_000)
    legacy_ticket_price(products(:one), 12_000)

    run_up

    assert_equal 22_000, migrated_product(products(:one)).price_cents
    assert_equal 22_000, payment.reload.amount_cents
  end

  test "uses a successful payment snapshot before its amount and falls back to the amount" do
    snapshot_payment = payments(:paid_payment)
    amount_payment = payments(:manual_payment)
    snapshot_cents = 4_300
    set_payment_snapshot(snapshot_payment, products(:two), snapshot_cents)
    set_payment_snapshot(amount_payment, products(:four), nil)
    payment_amounts = [snapshot_payment, amount_payment].index_with(&:amount_cents)

    run_up

    assert_equal snapshot_cents, migrated_product(products(:two)).price_cents
    assert_equal amount_payment.amount_cents, migrated_product(products(:four)).price_cents
    payment_amounts.each { |payment, amount| assert_equal amount, payment.reload.amount_cents }
  end

  test "uses current ticket pricing when there is no payment history" do
    participant = participants(:three)
    expected_cents = CongressPassPricing.new(
      attendance_option: participant.attendance_option,
      age_group: participant.age_group,
      payment_date: Date.current
    ).price_cents
    payment_amounts = Payment.pluck(:id, :amount_cents).to_h

    run_up

    assert_equal expected_cents, migrated_product(products(:three)).price_cents
    assert_equal payment_amounts, Payment.pluck(:id, :amount_cents).to_h
  end

  test "uses the saved amount for a hostel booking and leaves payment amounts unchanged" do
    payment_amounts = Payment.pluck(:id, :amount_cents).to_h

    run_up

    product_id = legacy_product_id("HostelBooking", @booking.id)
    assert_equal @hostel_price_cents, migrated_product(product_id).price_cents
    assert_equal payment_amounts, Payment.pluck(:id, :amount_cents).to_h
  end

  test "rolls back by restoring legacy price columns and payment snapshots without changing amounts" do
    payment_amounts = Payment.pluck(:id, :amount_cents).to_h
    run_up
    ticket_price_cents = migrated_product(products(:one)).price_cents
    paid_price_cents = migrated_product(products(:two)).price_cents
    @migration.migrate(:down)
    ActiveRecord::Base.connection.clear_cache!

    assert_equal ticket_price_cents, legacy_ticket_price_value(participant_tickets(:one).id)
    assert_equal paid_price_cents, payment_snapshot_value(payments(:paid_payment), products(:two))
    assert_equal payment_amounts, Payment.pluck(:id, :amount_cents).to_h
    assert_not ActiveRecord::Base.connection.column_exists?(:products, :price_cents)
    assert ActiveRecord::Base.connection.column_exists?(:participant_tickets, :price_cents)
    assert ActiveRecord::Base.connection.column_exists?(:payments, :product_prices_cents)
  end

  private

  def run_up
    @migration.migrate(:up)
    ActiveRecord::Base.connection.clear_cache!
    Product.reset_column_information
    Payment.reset_column_information
  end

  def legacy_payment
    StoreProductPrices::MigrationPayment
  end

  def legacy_ticket_price(product, cents)
    StoreProductPrices::MigrationTicket.where(id: product.productable_id).update_all(price_cents: cents)
  end

  def legacy_ticket_price_value(ticket_id)
    StoreProductPrices::MigrationTicket.find(ticket_id).price_cents
  end

  def set_payment_snapshot(payment, product, cents)
    snapshot = cents ? { product.id.to_s => cents } : {}
    legacy_payment.where(id: payment.id).update_all(product_prices_cents: snapshot)
  end

  def payment_snapshot_value(payment, product)
    legacy_payment.find(payment.id).product_prices_cents.fetch(product.id.to_s)
  end

  def legacy_product_id(type, productable_id)
    StoreProductPrices::MigrationProduct.find_by!(productable_type: type, productable_id:).id
  end

  def migrated_product(product_or_id)
    id = product_or_id.respond_to?(:id) ? product_or_id.id : product_or_id
    StoreProductPrices::MigrationProduct.find(id)
  end
end
