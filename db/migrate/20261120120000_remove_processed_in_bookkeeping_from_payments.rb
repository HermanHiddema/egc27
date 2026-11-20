class RemoveProcessedInBookkeepingFromPayments < ActiveRecord::Migration[8.1]
  def change
    remove_index :payments, :processed_in_bookkeeping
    remove_column :payments, :processed_in_bookkeeping, :boolean, default: false, null: false
  end
end
