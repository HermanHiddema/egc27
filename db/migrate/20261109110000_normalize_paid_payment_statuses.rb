class NormalizePaidPaymentStatuses < ActiveRecord::Migration[8.1]
  def up
    add_column :payments, :amount_refunded_cents, :integer, default: 0
    add_column :payments, :amount_charged_back_cents, :integer, default: 0

    # A null amount records an existing reversal whose amount is not known locally.
    execute <<~SQL
      UPDATE payments
      SET amount_refunded_cents = (SELECT NULLIF(SUM(refunds.amount_cents), 0) FROM refunds WHERE refunds.payment_id = payments.id),
          status = 'paid'
      WHERE status = 'refunded'
    SQL
    execute <<~SQL
      UPDATE payments
      SET amount_charged_back_cents = (SELECT NULLIF(SUM(chargebacks.amount_cents), 0) FROM chargebacks WHERE chargebacks.payment_id = payments.id AND chargebacks.reversed_at IS NULL),
          status = 'paid'
      WHERE status = 'charged_back'
    SQL
    execute <<~SQL
      UPDATE payments SET amount_refunded_cents = totals.amount_cents
      FROM (SELECT payment_id, SUM(amount_cents) AS amount_cents FROM refunds WHERE payment_id IS NOT NULL GROUP BY payment_id HAVING SUM(amount_cents) > 0) totals
      WHERE payments.id = totals.payment_id
    SQL
    execute <<~SQL
      UPDATE payments SET amount_charged_back_cents = totals.amount_cents
      FROM (SELECT payment_id, SUM(amount_cents) AS amount_cents FROM chargebacks WHERE payment_id IS NOT NULL AND reversed_at IS NULL GROUP BY payment_id HAVING SUM(amount_cents) > 0) totals
      WHERE payments.id = totals.payment_id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Refund and chargeback amounts cannot be preserved in the old payment schema"
  end
end
