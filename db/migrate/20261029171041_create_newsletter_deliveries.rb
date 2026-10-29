class CreateNewsletterDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :newsletter_deliveries do |t|
      t.references :newsletter, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :newsletter_subscription, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :delivered_at

      t.timestamps
    end

    add_index :newsletter_deliveries, [:newsletter_id, :newsletter_subscription_id], unique: true, name: "index_newsletter_deliveries_on_newsletter_and_subscription"
  end
end
