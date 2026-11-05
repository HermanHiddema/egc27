require "securerandom"

class RenameUnsubscribeTokenToSubscriptionToken < ActiveRecord::Migration[8.1]
  def up
    rename_column :newsletter_subscriptions, :unsubscribe_token, :subscription_token
    if index_name_exists?(:newsletter_subscriptions, "index_newsletter_subscriptions_on_unsubscribe_token")
      rename_index :newsletter_subscriptions,
        "index_newsletter_subscriptions_on_unsubscribe_token",
        "index_newsletter_subscriptions_on_subscription_token"
    end

    select_values("SELECT id FROM newsletter_subscriptions WHERE subscription_token IS NULL").each do |id|
      token = connection.quote(SecureRandom.urlsafe_base64(24))
      execute "UPDATE newsletter_subscriptions SET subscription_token = #{token} WHERE id = #{connection.quote(id)}"
    end

    change_column_null :newsletter_subscriptions, :subscription_token, false
  end

  def down
    change_column_null :newsletter_subscriptions, :subscription_token, true
    rename_column :newsletter_subscriptions, :subscription_token, :unsubscribe_token
    if index_name_exists?(:newsletter_subscriptions, "index_newsletter_subscriptions_on_subscription_token")
      rename_index :newsletter_subscriptions,
        "index_newsletter_subscriptions_on_subscription_token",
        "index_newsletter_subscriptions_on_unsubscribe_token"
    end
  end
end
