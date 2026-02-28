# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_28_120100) do
  create_table "articles", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_articles_on_user_id"
  end

  create_table "menu_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.integer "menu_id", null: false
    t.boolean "open_in_new_tab", default: false, null: false
    t.integer "page_id"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.boolean "visible", default: true, null: false
    t.index ["menu_id", "parent_id", "position"], name: "index_menu_items_on_menu_id_and_parent_id_and_position"
    t.index ["menu_id"], name: "index_menu_items_on_menu_id"
    t.index ["page_id"], name: "index_menu_items_on_page_id"
    t.index ["parent_id"], name: "index_menu_items_on_parent_id"
  end

  create_table "menus", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "location", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["location"], name: "index_menus_on_location", unique: true
  end

  create_table "pages", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_pages_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "full_name"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "articles", "users"
  add_foreign_key "menu_items", "menu_items", column: "parent_id"
  add_foreign_key "menu_items", "menus"
  add_foreign_key "menu_items", "pages"
end
