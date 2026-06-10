class CreateSponsors < ActiveRecord::Migration[8.1]
  def change
    create_table :sponsors do |t|
      t.string :name, null: false
      t.string :website
      t.jsonb :social_media_links, null: false, default: {}
      t.text :description

      t.timestamps
    end
  end
end
