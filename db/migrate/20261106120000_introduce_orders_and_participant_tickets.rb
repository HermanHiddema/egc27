class IntroduceOrdersAndParticipantTickets < ActiveRecord::Migration[8.1]
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
    create_table :participant_tickets do |t|
      t.references :participant, null: false, foreign_key: true, index: { unique: true }
      t.boolean :first_week, null: false, default: true
      t.boolean :weekend, null: false, default: true
      t.boolean :second_week, null: false, default: true
      t.timestamps
    end
    create_table :orders do |t|
      t.timestamps
    end
    create_table :products do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.references :productable, polymorphic: true, null: false, index: { unique: true }
      t.timestamps
      t.check_constraint "productable_type IN ('ParticipantTicket', 'HostelBooking')", name: "products_supported_productable_types"
    end
    add_reference :payments, :order, foreign_key: true
    LegacyPayment.reset_column_information

    LegacyParticipant.find_each do |participant|
      ticket = MigrationTicket.create!(participant_id: participant.id, first_week: participant.first_week,
        weekend: participant.weekend, second_week: participant.second_week,
        created_at: participant.created_at, updated_at: participant.updated_at)
      order = create_order_for("ParticipantTicket", ticket.id, participant.created_at)
      LegacyPayment.where(participant_id: participant.id, hostel_booking_id: nil).update_all(order_id: order.id)
    end
    LegacyBooking.find_each do |booking|
      order = create_order_for("HostelBooking", booking.id, booking.created_at)
      LegacyPayment.where(hostel_booking_id: booking.id, participant_id: nil).update_all(order_id: order.id)
    end

    unmatched_ids = LegacyPayment.where(order_id: nil).pluck(:id)
    raise "Cannot migrate payments without an unambiguous payee: #{unmatched_ids.join(', ')}" if unmatched_ids.any?

    change_column_null :payments, :order_id, false
    remove_check_constraint :payments, name: "payments_have_one_payee"
    remove_reference :payments, :participant, foreign_key: true
    remove_reference :payments, :hostel_booking, foreign_key: true
    remove_column :participants, :first_week, :boolean
    remove_column :participants, :weekend, :boolean
    remove_column :participants, :second_week, :boolean
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

    missing_tickets = select_values(<<~SQL)
      SELECT participants.id FROM participants
      LEFT JOIN participant_tickets ON participant_tickets.participant_id = participants.id
      WHERE participant_tickets.id IS NULL AND participants.participant_type <> 'visitor'
    SQL
    if missing_tickets.any?
      raise ActiveRecord::IrreversibleMigration, "Participants without tickets: #{missing_tickets.join(', ')}"
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

    # Visitors without tickets have no attendance data; restore the old defaults.
    add_column :participants, :first_week, :boolean, null: false, default: true
    add_column :participants, :weekend, :boolean, null: false, default: true
    add_column :participants, :second_week, :boolean, null: false, default: true
    execute <<~SQL
      UPDATE participants SET first_week = tickets.first_week, weekend = tickets.weekend, second_week = tickets.second_week
      FROM participant_tickets tickets WHERE tickets.participant_id = participants.id
    SQL
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
  end

  private

  def create_order_for(type, id, created_at)
    order = MigrationOrder.create!(created_at: created_at, updated_at: created_at)
    MigrationProduct.create!(order_id: order.id, productable_type: type, productable_id: id,
      created_at: created_at, updated_at: created_at)
    order
  end
end
