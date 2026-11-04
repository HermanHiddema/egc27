class AddProcessedInBookkeepingToPayments < ActiveRecord::Migration[8.1]
  def change
    # Tracks whether a completed payment has been entered in the bookkeeping,
    # so admins can work through the list of payments still to be processed.
    add_column :payments, :processed_in_bookkeeping, :boolean, null: false, default: false
    add_index :payments, :processed_in_bookkeeping
  end
end
