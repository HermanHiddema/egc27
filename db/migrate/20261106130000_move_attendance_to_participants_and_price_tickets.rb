class MoveAttendanceToParticipantsAndPriceTickets < ActiveRecord::Migration[8.1]
  # Snapshot of the pricing rules when the price field was introduced.
  PRICES = {
    [true, true, true] => [190, 220, 260, 300],
    [true, true, false] => [130, 160, 190, 230],
    [false, true, true] => [130, 160, 190, 230],
    [false, true, false] => [50, 60, 70, 80]
  }.freeze

  def up
    add_column :participants, :first_week, :boolean, default: true
    add_column :participants, :weekend, :boolean, default: true
    add_column :participants, :second_week, :boolean, default: true
    add_column :participant_tickets, :price_cents, :integer

    # Ticket-free registrations from the previous version did not record a
    # period. Keep it unknown rather than assuming the defaults applied.
    execute "UPDATE participants SET first_week = NULL, weekend = NULL, second_week = NULL"
    execute <<~SQL
      UPDATE participants SET first_week = tickets.first_week, weekend = tickets.weekend, second_week = tickets.second_week
      FROM participant_tickets tickets WHERE tickets.participant_id = participants.id
    SQL

    tier = if Date.current <= Date.new(2026, 8, 31)
      0
    elsif Date.current <= Date.new(2027, 1, 31)
      1
    elsif Date.current <= Date.new(2027, 5, 31)
      2
    else
      3
    end
    unknown_prices = []
    select_all(<<~SQL).each do |row|
      SELECT tickets.id, participants.first_week, participants.weekend, participants.second_week, participants.age_group,
             (SELECT payments.amount_cents FROM products JOIN payments ON payments.order_id = products.order_id
              WHERE products.productable_type = 'ParticipantTicket' AND products.productable_id = tickets.id
                AND payments.status IN ('open', 'pending', 'authorized', 'paid', 'refunded', 'charged_back')
              ORDER BY CASE WHEN payments.status = 'paid' THEN 0 WHEN payments.status IN ('open', 'pending', 'authorized') THEN 1 ELSE 2 END, payments.created_at DESC, payments.id DESC
              LIMIT 1) AS started_payment_cents
      FROM participant_tickets tickets JOIN participants ON participants.id = tickets.participant_id
    SQL
      prices = PRICES[[row["first_week"], row["weekend"], row["second_week"]]]
      if row["started_payment_cents"].to_i.positive?
        cents = row["started_payment_cents"]
      elsif prices && %w[0-11 12-17 18-49 50+].include?(row["age_group"])
        percentage = { "0-11" => 20, "12-17" => 50 }.fetch(row["age_group"], 100)
        cents = ((prices[tier] * percentage + 50) / 100) * 100
      else
        unknown_prices << row["id"]
        next
      end
      execute "UPDATE participant_tickets SET price_cents = #{cents} WHERE id = #{Integer(row['id'])}"
    end
    say "Ticket prices could not be calculated for ticket IDs: #{unknown_prices.join(', ')}" if unknown_prices.any?
    unknown_attendance = select_values("SELECT id FROM participants WHERE first_week IS NULL OR weekend IS NULL OR second_week IS NULL ORDER BY id")
    say "Attendance is unknown for participant IDs: #{unknown_attendance.join(', ')}" if unknown_attendance.any?

    remove_column :participant_tickets, :first_week, :boolean
    remove_column :participant_tickets, :weekend, :boolean
    remove_column :participant_tickets, :second_week, :boolean
  end

  def down
    without_tickets = select_values(<<~SQL)
      SELECT participants.id FROM participants LEFT JOIN participant_tickets ON participant_tickets.participant_id = participants.id
      WHERE participant_tickets.id IS NULL AND (participants.first_week IS NOT NULL OR participants.weekend IS NOT NULL OR participants.second_week IS NOT NULL)
    SQL
    if without_tickets.any?
      raise ActiveRecord::IrreversibleMigration, "Attendance would be lost for participants without tickets: #{without_tickets.join(', ')}"
    end
    invalid = select_values(<<~SQL)
      SELECT tickets.id FROM participant_tickets tickets JOIN participants ON participants.id = tickets.participant_id
      WHERE participants.first_week IS NULL OR participants.weekend IS NULL OR participants.second_week IS NULL
    SQL
    raise ActiveRecord::IrreversibleMigration, "Ticket attendance is unknown: #{invalid.join(', ')}" if invalid.any?

    priced_tickets = select_values("SELECT id FROM participant_tickets WHERE price_cents IS NOT NULL ORDER BY id")
    if priced_tickets.any?
      raise ActiveRecord::IrreversibleMigration, "Ticket prices would be lost: #{priced_tickets.join(', ')}"
    end

    add_column :participant_tickets, :first_week, :boolean, null: false, default: true
    add_column :participant_tickets, :weekend, :boolean, null: false, default: true
    add_column :participant_tickets, :second_week, :boolean, null: false, default: true
    execute <<~SQL
      UPDATE participant_tickets SET first_week = participants.first_week, weekend = participants.weekend, second_week = participants.second_week
      FROM participants WHERE participants.id = participant_tickets.participant_id
    SQL
    remove_column :participant_tickets, :price_cents, :integer
    remove_column :participants, :first_week, :boolean
    remove_column :participants, :weekend, :boolean
    remove_column :participants, :second_week, :boolean
  end
end
