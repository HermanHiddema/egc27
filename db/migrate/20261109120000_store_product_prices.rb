class StoreProductPrices < ActiveRecord::Migration[8.1]
  class MigrationProduct < ActiveRecord::Base
    self.table_name = "products"
  end

  class MigrationTicket < ActiveRecord::Base
    self.table_name = "participant_tickets"
  end

  class MigrationParticipant < ActiveRecord::Base
    self.table_name = "participants"
  end

  class MigrationBooking < ActiveRecord::Base
    self.table_name = "hostel_bookings"
  end

  class MigrationPayment < ActiveRecord::Base
    self.table_name = "payments"
  end

  class MigrationOrder < ActiveRecord::Base
    self.table_name = "orders"
  end

  def up
    ensure_one_product_per_order
    add_column :products, :price_cents, :integer
    [MigrationProduct, MigrationTicket, MigrationParticipant, MigrationBooking, MigrationPayment, MigrationOrder].each(&:reset_column_information)

    MigrationProduct.find_each do |product|
      price = if product.productable_type == "HostelBooking"
        MigrationBooking.find(product.productable_id).amount_cents
      else
        ticket_price(product)
      end
      raise "Could not determine price for Product #{product.id}" unless price.to_i.positive?

      product.update_columns(price_cents: price)
    end

    change_column_null :products, :price_cents, false
    remove_column :participant_tickets, :price_cents, :integer
    remove_column :payments, :product_prices_cents, :jsonb, if_exists: true
  end

  def down
    add_column :payments, :product_prices_cents, :jsonb unless column_exists?(:payments, :product_prices_cents)
    add_column :participant_tickets, :price_cents, :integer
    [MigrationProduct, MigrationTicket].each(&:reset_column_information)
    MigrationProduct.where(productable_type: "ParticipantTicket").find_each do |product|
      MigrationTicket.where(id: product.productable_id).update_all(price_cents: product.price_cents)
    end
    MigrationPayment.reset_column_information
    MigrationPayment.find_each do |payment|
      product = MigrationProduct.find_by(order_id: payment.order_id)
      payment.update_columns(product_prices_cents: { product.id.to_s => product.price_cents }) if product
    end
    remove_column :products, :price_cents
  end

  private

  def ensure_one_product_per_order
    name = "index_products_on_order_id"
    return if index_exists?(:products, :order_id, unique: true, name:)

    if index_exists?(:products, :order_id, name:)
      remove_index :products, name:
    end
    add_index :products, :order_id, unique: true, name:
  end

  def ticket_price(product)
    order = MigrationOrder.find(product.order_id)
    payments = MigrationPayment.where(order_id: order.id)
    # Preserve a live Mollie quote and any historical successful amount.
    active_amount = payments.where(provider: "mollie", status: %w[open pending authorized])
      .order(created_at: :desc, id: :desc).pick(:amount_cents)
    return active_amount if active_amount.to_i.positive?

    paid_payment = payments.where(status: %w[paid refunded charged_back])
      .order(created_at: :desc, id: :desc).first
    paid_amount = snapshot_amount(paid_payment, product) || paid_payment&.amount_cents
    return paid_amount if paid_amount.to_i.positive?

    participant = MigrationParticipant.find(MigrationTicket.find(product.productable_id).participant_id)
    option = case [participant.first_week, participant.weekend, participant.second_week]
    when [true, true, true] then "all_events"
    when [true, true, false] then "first_week_plus_weekend"
    when [false, true, true] then "weekend_plus_second_week"
    when [false, true, false] then "weekend_only"
    end
    return unless option && Participant::AGE_GROUPS.include?(participant.age_group)

    CongressPassPricing.new(
      attendance_option: option,
      age_group: participant.age_group,
      payment_date: Date.current
    ).price_cents
  end

  def snapshot_amount(payment, product)
    return unless payment&.has_attribute?(:product_prices_cents) && payment.product_prices_cents.is_a?(Hash)

    payment.product_prices_cents[product.id.to_s] || payment.product_prices_cents[product.id]
  end
end
