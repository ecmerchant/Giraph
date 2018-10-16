# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20181016001810) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string   "user"
    t.string   "seller_id"
    t.string   "mws_auth_token"
    t.string   "aws_access_key_id"
    t.string   "secret_key"
    t.float    "shipping_weight"
    t.float    "max_roi"
    t.float    "listing_shipping"
    t.float    "delivery_fee"
    t.float    "payoneer_fee"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
    t.string   "cw_api_token"
    t.string   "cw_room_id"
    t.string   "us_seller_id1"
    t.string   "us_aws_access_key_id1"
    t.string   "us_secret_key1"
    t.string   "us_seller_id2"
    t.string   "us_aws_access_key_id2"
    t.string   "us_secret_key2"
    t.float    "exchange_rate"
    t.float    "calc_ex_rate"
  end

  create_table "order_lists", force: :cascade do |t|
    t.string   "user"
    t.datetime "order_date"
    t.string   "order_id"
    t.string   "sku"
    t.float    "sales"
    t.float    "amazon_fee"
    t.float    "ex_rate"
    t.float    "cost_price"
    t.float    "listing_shipping"
    t.float    "profit"
    t.float    "roi"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  create_table "products", force: :cascade do |t|
    t.string   "asin"
    t.string   "sku"
    t.float    "jp_price"
    t.float    "jp_shipping"
    t.float    "jp_point"
    t.float    "cost_price"
    t.float    "size_length"
    t.float    "size_width"
    t.float    "size_height"
    t.float    "size_weight"
    t.float    "shipping_weight"
    t.float    "us_price"
    t.float    "us_shipping"
    t.float    "us_point"
    t.float    "max_roi"
    t.float    "us_listing_price"
    t.float    "referral_fee"
    t.float    "referral_fee_rate"
    t.float    "variable_closing_fee"
    t.float    "listing_shipping"
    t.float    "delivery_fee"
    t.float    "exchange_rate"
    t.float    "payoneer_fee"
    t.float    "calc_ex_rate"
    t.float    "profit"
    t.float    "minimum_listing_price"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
    t.string   "user"
    t.float    "roi"
    t.boolean  "manual_update"
    t.boolean  "on_sale"
    t.string   "jp_title"
    t.index ["sku", "user"], name: "for_upsert", unique: true, using: :btree
    t.index ["user", "sku"], name: "index_products_on_user_and_sku", unique: true, using: :btree
  end

  create_table "shipping_costs", force: :cascade do |t|
    t.string   "user"
    t.string   "name"
    t.float    "weight"
    t.float    "cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.boolean  "admin_flg"
    t.index ["email"], name: "index_users_on_email", unique: true, using: :btree
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  end

end
