class AddConsentsToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :accepted_terms_and_conditions, :boolean, null: false, default: false
    add_column :participants, :accepted_privacy_policy, :boolean, null: false, default: false
    add_column :participants, :image_use_consent, :boolean, null: false, default: false
  end
end
