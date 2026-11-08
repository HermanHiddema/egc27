class IntroduceOrdersAndParticipantTickets < ActiveRecord::Migration[8.1]
  # Snapshot of the pricing rules at the time this migration was written.
  PRICES = {
    [true, true, true] => [190, 220, 260, 300],
    [true, true, false] => [130, 160, 190, 230],
    [false, true, true] => [130, 160, 190, 230],
    [false, true, false] => [50, 60, 70, 80]
  }.freeze
  STARTED_STATUSES = %w[open pending authorized paid refunded charged_back].freeze

  class LegacyParticipant < ActiveRecord::Base
    self.table_name = "participants"
  end
  class LegacyBooking < ActiveRecord::Base
    self.table_name = "hostel_bookings"
  end
  class LegacyPayment < ActiveRecord::Base
    self.table_name = "payments"
  end
  class MigrationTicket < ActiveRecord::Base
    self.table_name = "participant_tickets"
  end
  class MigrationOrder < ActiveRecord::Base
    self.table_name = "orders"
  end
  class MigrationProduct < ActiveRecord::Base
    self.table_name = "products"
  end

  def up
    # Allow unknown periods, as in databases that ran the earlier two migrations.
    [:first_week, :weekend, :second_week].each { |field| change_column_null :participants, field, true }

    create_table :participant_tickets do |t|
      t.references :participant, null: false, foreign_key: true, index: { unique: true }
      t.integer :price_cents
      t.timestamps
    end
    create_table(:orders) { |t| t.timestamps }
    create_table :products do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.references :productable, polymorphic: true, null: false, index: { unique: true }
      t.timestamps
      t.check_constraint "productable_type IN ('ParticipantTicket', 'HostelBooking')", name: "products_supported_productable_types"
    end
    add_reference :payments, :order, foreign_key: true
    [LegacyParticipant, LegacyBooking, LegacyPayment, MigrationTicket, MigrationOrder, MigrationProduct].each(&:reset_column_information)

    unknown_prices = []
    LegacyParticipant.find_each do |participant|
      participant_payments = LegacyPayment.where(participant_id: participant.id, hostel_booking_id: nil)
      # Keep historical payments even if the participant is now a visitor.
      next if participant.participant_type != "player" && !participant_payments.exists?

      price = price_for(participant, participant_payments)
      ticket = MigrationTicket.create!(participant_id: participant.id, price_cents: price,
        created_at: participant.created_at, updated_at: participant.updated_at)
      unknown_prices << ticket.id unless price
      order = create_order_for("ParticipantTicket", ticket.id, participant.created_at)
      participant_payments.update_all(order_id: order.id)
    end
    LegacyBooking.find_each do |booking|
      order = create_order_for("HostelBooking", booking.id, booking.created_at)
      LegacyPayment.where(hostel_booking_id: booking.id, participant_id: nil).update_all(order_id: order.id)
    end

    unmatched_ids = LegacyPayment.where(order_id: nil).pluck(:id)
    raise "Cannot migrate payments without an unambiguous payee: #{unmatched_ids.join(', ')}" if unmatched_ids.any?
    say "Ticket prices could not be calculated for ticket IDs: #{unknown_prices.join(', ')}" if unknown_prices.any?

    change_column_null :payments, :order_id, false
    remove_check_constraint :payments, name: "payments_have_one_payee"
    remove_reference :payments, :participant, foreign_key: true
    remove_reference :payments, :hostel_booking, foreign_key: true
  end

  def down
    ambiguous_orders = select_values(<<~SQL)
      SELECT payments.order_id FROM payments
      LEFT JOIN products ON products.order_id = payments.order_id
      GROUP BY payments.order_id HAVING COUNT(DISTINCT products.id) <> 1
    SQL
    if ambiguous_orders.any?
      raise ActiveRecord::IrreversibleMigration, "Payments on orders without exactly one product: #{ambiguous_orders.join(', ')}"
    end

    unmatched_payments = select_values(<<~SQL)
      SELECT payments.id FROM payments
      LEFT JOIN products ON products.order_id = payments.order_id
      LEFT JOIN participant_tickets ON products.productable_type = 'ParticipantTicket' AND participant_tickets.id = products.productable_id
      LEFT JOIN hostel_bookings ON products.productable_type = 'HostelBooking' AND hostel_bookings.id = products.productable_id
      WHERE participant_tickets.id IS NULL AND hostel_bookings.id IS NULL
    SQL
    if unmatched_payments.any?
      raise ActiveRecord::IrreversibleMigration, "Payments without a restorable payee: #{unmatched_payments.join(', ')}"
    end

    priced_tickets = select_values("SELECT id FROM participant_tickets WHERE price_cents IS NOT NULL ORDER BY id")
    if priced_tickets.any?
      raise ActiveRecord::IrreversibleMigration, "Ticket prices would be lost: #{priced_tickets.join(', ')}"
    end
    unknown_attendance = select_values("SELECT id FROM participants WHERE first_week IS NULL OR weekend IS NULL OR second_week IS NULL ORDER BY id")
    if unknown_attendance.any?
      raise ActiveRecord::IrreversibleMigration, "Attendance is unknown for participant IDs: #{unknown_attendance.join(', ')}"
    end

    add_reference :payments, :participant, foreign_key: true
    add_reference :payments, :hostel_booking, foreign_key: true
    execute <<~SQL
      UPDATE payments SET participant_id = tickets.participant_id
      FROM products JOIN participant_tickets tickets ON products.productable_id = tickets.id
      WHERE products.productable_type = 'ParticipantTicket' AND products.order_id = payments.order_id
    SQL
    execute <<~SQL
      UPDATE payments SET hostel_booking_id = products.productable_id
      FROM products WHERE products.productable_type = 'HostelBooking' AND products.order_id = payments.order_id
    SQL
    add_check_constraint :payments, "(participant_id IS NULL) <> (hostel_booking_id IS NULL)", name: "payments_have_one_payee"
    remove_reference :payments, :order, foreign_key: true
    drop_table :products
    drop_table :orders
    drop_table :participant_tickets
    [:first_week, :weekend, :second_week].each { |field| change_column_null :participants, field, false }
  end

  private

  def price_for(participant, payments)
    started_payment = payments.where(status: STARTED_STATUSES).order(
      Arel.sql("CASE WHEN status = 'paid' THEN 0 WHEN status IN ('open', 'pending', 'authorized') THEN 1 ELSE 2 END"),
      created_at: :desc, id: :desc
    ).first
    return started_payment.amount_cents if started_payment && started_payment.amount_cents.to_i.positive?

    prices = PRICES[[participant.first_week, participant.weekend, participant.second_week]]
    return unless prices && %w[0-11 12-17 18-49 50+].include?(participant.age_group)

    tier = if Date.current <= Date.new(2026, 8, 31)
      0
    elsif Date.current <= Date.new(2027, 1, 31)
      1
    elsif Date.current <= Date.new(2027, 5, 31)
      2
    else
      3
    end
    percentage = { "0-11" => 20, "12-17" => 50 }.fetch(participant.age_group, 100)
    ((prices[tier] * percentage + 50) / 100) * 100
  end

  def create_order_for(type, id, created_at)
    order = MigrationOrder.create!(created_at: created_at, updated_at: created_at)
    MigrationProduct.create!(order_id: order.id, productable_type: type, productable_id: id,
      created_at: created_at, updated_at: created_at)
    order
  end
end
