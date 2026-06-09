class CreateNewsletterSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :newsletter_subscriptions do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.boolean :subscribed, null: false, default: true
      t.string :unsubscribe_token, null: false
      t.datetime :unsubscribed_at

      t.timestamps
    end

    add_index :newsletter_subscriptions, :email, unique: true
    add_index :newsletter_subscriptions, :unsubscribe_token, unique: true
  end
end
