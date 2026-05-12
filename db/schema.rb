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

ActiveRecord::Schema[7.1].define(version: 2026_05_11_190000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.integer "price"
    t.integer "stock_quantity"
    t.boolean "favorite", default: false
    t.text "memo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "archived", default: false, null: false
    t.index ["archived"], name: "index_items_on_archived"
    t.index ["user_id"], name: "index_items_on_user_id"
  end

  create_table "usage_logs", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.bigint "user_id", null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.integer "rating"
    t.text "review"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id", "finished_at"], name: "index_usage_logs_on_item_id_and_finished_at"
    t.index ["item_id"], name: "index_usage_logs_on_item_id"
    t.index ["item_id"], name: "index_usage_logs_on_item_id_where_in_use", unique: true, where: "(finished_at IS NULL)"
    t.index ["user_id", "finished_at"], name: "index_usage_logs_on_user_id_and_finished_at"
    t.index ["user_id"], name: "index_usage_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "items", "users"
  add_foreign_key "usage_logs", "items"
  add_foreign_key "usage_logs", "users"
end
