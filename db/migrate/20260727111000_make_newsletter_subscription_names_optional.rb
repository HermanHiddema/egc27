class MakeNewsletterSubscriptionNamesOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :newsletter_subscriptions, :first_name, true
    change_column_null :newsletter_subscriptions, :last_name, true
  end
end
