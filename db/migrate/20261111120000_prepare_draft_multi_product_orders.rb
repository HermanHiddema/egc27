class PrepareDraftMultiProductOrders < ActiveRecord::Migration[8.1]
  def up
    add_column :orders, :user_id, :bigint
    add_column :orders, :status, :string, null: false, default: "submitted"

    execute <<~SQL
      UPDATE orders
      SET user_id = COALESCE(
        (SELECT participants.user_id FROM products
          JOIN participant_tickets ON products.productable_type = 'ParticipantTicket'
            AND participant_tickets.id = products.productable_id
          JOIN participants ON participants.id = participant_tickets.participant_id
          WHERE products.order_id = orders.id LIMIT 1),
        (SELECT hostel_bookings.user_id FROM products
          JOIN hostel_bookings ON products.productable_type = 'HostelBooking'
            AND hostel_bookings.id = products.productable_id
          WHERE products.order_id = orders.id LIMIT 1)
      )
    SQL
    change_column_null :orders, :user_id, false
    add_foreign_key :orders, :users
    add_index :orders, :user_id
    add_index :orders, :user_id, unique: true, where: "status = 'draft'", name: "index_orders_one_draft_per_user"

    remove_index :products, :order_id
    add_index :products, :order_id
    remove_index :participant_tickets, :participant_id
    add_index :participant_tickets, :participant_id
    add_column :participant_tickets, :invalidated_at, :datetime
  end

  def down
    remove_column :participant_tickets, :invalidated_at
    remove_index :participant_tickets, :participant_id
    add_index :participant_tickets, :participant_id, unique: true
    remove_index :products, :order_id
    add_index :products, :order_id, unique: true
    remove_index :orders, name: "index_orders_one_draft_per_user"
    remove_index :orders, :user_id
    remove_foreign_key :orders, :users
    remove_column :orders, :status
    remove_column :orders, :user_id
  end
end
