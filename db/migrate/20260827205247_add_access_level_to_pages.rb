class AddAccessLevelToPages < ActiveRecord::Migration[8.1]
  def change
    # Pages are public by default; "authenticated" pages are only reachable by
    # signed-in users and are hidden from menus and listings for everyone else.
    add_column :pages, :access_level, :string, null: false, default: "public"
  end
end
