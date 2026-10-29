class AllowNewsletterSubscriptionUnsubscribeTokenToBeNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :newsletter_subscriptions, :unsubscribe_token, true
  end
end
