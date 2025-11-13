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

ActiveRecord::Schema[8.0].define(version: 2025_11_12_214423) do
  create_table "balance_transactions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "amount_cents", null: false
    t.string "transaction_type", null: false
    t.string "description"
    t.integer "queue_item_id"
    t.integer "balance_after_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["queue_item_id"], name: "index_balance_transactions_on_queue_item_id"
    t.index ["user_id", "created_at"], name: "index_balance_transactions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_balance_transactions_on_user_id"
  end

  create_table "queue_items", force: :cascade do |t|
    t.integer "song_id"
    t.integer "queue_session_id", null: false
    t.integer "user_id"
    t.integer "base_price_cents", default: 100, null: false
    t.integer "vote_count", default: 0, null: false
    t.integer "base_priority", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "played_at"
    t.boolean "is_currently_playing", default: false
    t.string "cover_url"
    t.integer "duration_ms"
    t.string "user_display_name"
    t.integer "vote_score", default: 0
    t.string "title"
    t.string "artist"
    t.string "spotify_id"
    t.string "preview_url"
    t.integer "position_paid_cents"
    t.integer "position_guaranteed"
    t.integer "refund_amount_cents", default: 0, null: false
    t.integer "inserted_at_position"
    t.index ["played_at"], name: "index_queue_items_on_played_at"
    t.index ["position_guaranteed"], name: "index_queue_items_on_position_guaranteed"
    t.index ["queue_session_id"], name: "index_queue_items_on_queue_session_id"
    t.index ["song_id"], name: "index_queue_items_on_song_id"
    t.index ["user_id"], name: "index_queue_items_on_user_id"
  end

  create_table "queue_sessions", force: :cascade do |t|
    t.integer "venue_id", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "currently_playing_id"
    t.boolean "is_playing", default: false
    t.datetime "playback_started_at"
    t.string "join_code", null: false
    t.string "status", default: "active", null: false
    t.datetime "code_expires_at"
    t.string "access_code"
    t.datetime "last_activity_at"
    t.index ["access_code"], name: "index_queue_sessions_on_access_code", unique: true
    t.index ["currently_playing_id"], name: "index_queue_sessions_on_currently_playing_id"
    t.index ["join_code"], name: "index_queue_sessions_on_join_code"
    t.index ["last_activity_at"], name: "index_queue_sessions_on_last_activity_at"
    t.index ["venue_id", "is_active"], name: "index_queue_sessions_on_venue_id_and_is_active"
    t.index ["venue_id", "status"], name: "index_queue_sessions_on_venue_id_and_status"
  end

  create_table "songs", force: :cascade do |t|
    t.string "title", null: false
    t.string "artist", null: false
    t.string "spotify_id"
    t.string "cover_url"
    t.integer "duration_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "preview_url"
  end

  create_table "users", force: :cascade do |t|
    t.string "display_name", null: false
    t.string "auth_provider"
    t.string "access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.string "password_digest"
    t.string "canonical_email"
    t.integer "role", default: 0, null: false
    t.integer "balance_cents", default: 10000, null: false
    t.index ["balance_cents"], name: "index_users_on_balance_cents"
    t.index ["canonical_email"], name: "index_users_on_canonical_email_unique", unique: true, where: "canonical_email IS NOT NULL /*application='Queuemusic'*/"
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "venues", force: :cascade do |t|
    t.string "name", null: false
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "capacity"
    t.bigint "host_user_id"
    t.boolean "pricing_enabled", default: true, null: false
    t.integer "base_price_cents", default: 100, null: false
    t.integer "min_price_cents", default: 1, null: false
    t.integer "max_price_cents", default: 50000, null: false
    t.decimal "price_multiplier", precision: 10, scale: 2, default: "1.0", null: false
    t.integer "peak_hours_start", default: 19, null: false
    t.integer "peak_hours_end", default: 23, null: false
    t.decimal "peak_hours_multiplier", precision: 10, scale: 2, default: "1.5", null: false
    t.index ["host_user_id"], name: "index_venues_on_host_user_id"
  end

  add_foreign_key "balance_transactions", "queue_items"
  add_foreign_key "balance_transactions", "users"
  add_foreign_key "queue_items", "queue_sessions"
  add_foreign_key "queue_items", "songs"
  add_foreign_key "queue_items", "users"
  add_foreign_key "queue_sessions", "venues"
  add_foreign_key "venues", "users", column: "host_user_id"
end
