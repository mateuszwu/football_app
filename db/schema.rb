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

ActiveRecord::Schema[8.1].define(version: 2026_06_06_061500) do
  create_table "match_day_players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "match_day_id", null: false
    t.integer "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["match_day_id", "player_id"], name: "index_match_day_players_on_match_day_id_and_player_id", unique: true
    t.index ["match_day_id"], name: "index_match_day_players_on_match_day_id"
    t.index ["player_id"], name: "index_match_day_players_on_player_id"
  end

  create_table "match_day_vote_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "match_day_player_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.index ["match_day_player_id"], name: "index_match_day_vote_tokens_on_match_day_player_id", unique: true
    t.index ["token"], name: "index_match_day_vote_tokens_on_token", unique: true
  end

  create_table "match_days", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "played_on", null: false
    t.integer "season_id", null: false
    t.string "status", default: "setup", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id", "played_on"], name: "index_match_days_on_season_id_and_played_on", unique: true
    t.index ["season_id"], name: "index_match_days_on_season_id"
    t.index ["status"], name: "index_match_days_on_status"
  end

  create_table "players", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "approval_status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.string "name", null: false
    t.string "nickname", null: false
    t.string "phone", null: false
    t.string "role_code", default: "ANY", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_players_on_active"
    t.index ["approval_status"], name: "index_players_on_approval_status"
    t.index ["nickname"], name: "index_players_on_nickname", unique: true
    t.index ["phone"], name: "index_players_on_phone", unique: true
    t.index ["role_code"], name: "index_players_on_role_code"
  end

  create_table "seasons", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "def_vote_bonus", default: 10, null: false
    t.integer "elo_k_factor", default: 32, null: false
    t.date "ends_on"
    t.integer "initial_elo", default: 1000, null: false
    t.integer "mvp_vote_bonus", default: 10, null: false
    t.string "name", null: false
    t.date "starts_on", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_seasons_on_active"
    t.index ["name"], name: "index_seasons_on_name", unique: true
    t.index ["starts_on", "ends_on"], name: "index_seasons_on_starts_on_and_ends_on"
  end

  create_table "team_players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "player_id", null: false
    t.integer "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_team_players_on_player_id"
    t.index ["team_id", "player_id"], name: "index_team_players_on_team_id_and_player_id", unique: true
    t.index ["team_id"], name: "index_team_players_on_team_id"
  end

  create_table "team_setups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "match_day_id", null: false
    t.datetime "updated_at", null: false
    t.index ["match_day_id"], name: "index_team_setups_on_match_day_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "team_setup_id", null: false
    t.string "team_type", null: false
    t.datetime "updated_at", null: false
    t.index ["team_setup_id"], name: "index_teams_on_team_setup_id"
    t.index ["team_type"], name: "index_teams_on_team_type"
  end

  add_foreign_key "match_day_players", "match_days"
  add_foreign_key "match_day_players", "players"
  add_foreign_key "match_day_vote_tokens", "match_day_players"
  add_foreign_key "match_days", "seasons"
  add_foreign_key "team_players", "players"
  add_foreign_key "team_players", "teams"
  add_foreign_key "team_setups", "match_days"
  add_foreign_key "teams", "team_setups"
end
