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

ActiveRecord::Schema[8.1].define(version: 2026_07_20_100100) do
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
    t.datetime "expires_at", null: false
    t.integer "match_day_player_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.index ["match_day_player_id"], name: "index_match_day_vote_tokens_on_match_day_player_id", unique: true
    t.index ["token"], name: "index_match_day_vote_tokens_on_token", unique: true
  end

  create_table "match_day_votes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "def_player_id", null: false
    t.integer "match_day_vote_token_id", null: false
    t.integer "mvp_player_id", null: false
    t.datetime "submitted_at", null: false
    t.datetime "updated_at", null: false
    t.index ["def_player_id"], name: "index_match_day_votes_on_def_player_id"
    t.index ["match_day_vote_token_id"], name: "index_match_day_votes_on_match_day_vote_token_id", unique: true
    t.index ["mvp_player_id"], name: "index_match_day_votes_on_mvp_player_id"
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

  create_table "match_goals", force: :cascade do |t|
    t.integer "assistant_team_player_id"
    t.integer "away_score_after", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "home_score_after", default: 0, null: false
    t.integer "match_id", null: false
    t.boolean "own_goal", default: false, null: false
    t.datetime "scored_at", null: false
    t.integer "scorer_team_player_id", null: false
    t.integer "scoring_team_id", null: false
    t.datetime "undone_at"
    t.datetime "updated_at", null: false
    t.index ["assistant_team_player_id"], name: "index_match_goals_on_assistant_team_player_id"
    t.index ["match_id", "assistant_team_player_id", "undone_at"], name: "idx_on_match_id_assistant_team_player_id_undone_at_f67a413d96"
    t.index ["match_id", "scorer_team_player_id", "undone_at"], name: "idx_on_match_id_scorer_team_player_id_undone_at_97141c7614"
    t.index ["match_id", "scoring_team_id", "undone_at"], name: "idx_on_match_id_scoring_team_id_undone_at_cb6ae330f6"
    t.index ["match_id", "undone_at"], name: "index_match_goals_on_match_id_and_undone_at"
    t.index ["match_id"], name: "index_match_goals_on_match_id"
    t.index ["own_goal", "undone_at"], name: "index_match_goals_on_own_goal_and_undone_at"
    t.index ["scorer_team_player_id"], name: "index_match_goals_on_scorer_team_player_id"
    t.index ["scoring_team_id"], name: "index_match_goals_on_scoring_team_id"
  end

  create_table "matches", force: :cascade do |t|
    t.boolean "all_roster_players_on_pitch", default: false, null: false
    t.integer "away_score", default: 0
    t.integer "away_team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "elo_processed_at"
    t.datetime "finished_at"
    t.integer "home_score", default: 0
    t.integer "home_team_id", null: false
    t.integer "lineup_source_match_id"
    t.string "lineup_source_type"
    t.integer "match_day_id", null: false
    t.datetime "performance_processed_at"
    t.boolean "ranked", default: true, null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.integer "team_setup_id"
    t.integer "timer_beep_count", default: 3, null: false
    t.integer "timer_interval_seconds", default: 300, null: false
    t.datetime "updated_at", null: false
    t.index ["away_team_id"], name: "index_matches_on_away_team_id"
    t.index ["home_team_id"], name: "index_matches_on_home_team_id"
    t.index ["lineup_source_match_id"], name: "index_matches_on_lineup_source_match_id"
    t.index ["match_day_id", "home_team_id", "away_team_id"], name: "idx_on_match_day_id_home_team_id_away_team_id_f7a6ad2a0b", unique: true
    t.index ["match_day_id"], name: "index_matches_on_match_day_id"
    t.index ["status", "away_team_id"], name: "index_matches_on_status_and_away_team_id"
    t.index ["status", "home_team_id"], name: "index_matches_on_status_and_home_team_id"
    t.index ["status", "match_day_id"], name: "index_matches_on_status_and_match_day_id"
    t.index ["team_setup_id"], name: "index_matches_on_team_setup_id"
  end

  create_table "player_rating_changes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "elo_delta"
    t.decimal "elo_k_value", precision: 6, scale: 2
    t.integer "match_day_id", null: false
    t.integer "match_id"
    t.integer "new_elo_score"
    t.integer "old_elo_score"
    t.decimal "performance_delta", precision: 8, scale: 2
    t.decimal "player_advantage_elo", precision: 6, scale: 2
    t.integer "player_id", null: false
    t.string "rating_scope", null: false
    t.string "reason", null: false
    t.integer "season_id", null: false
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.index ["match_day_id"], name: "index_player_rating_changes_on_match_day_id"
    t.index ["match_id"], name: "index_player_rating_changes_on_match_id"
    t.index ["player_id", "season_id", "rating_scope", "source_type", "created_at"], name: "index_rating_changes_on_player_season_source_created"
    t.index ["player_id"], name: "index_player_rating_changes_on_player_id"
    t.index ["season_id"], name: "index_player_rating_changes_on_season_id"
  end

  create_table "player_season_stats", force: :cascade do |t|
    t.integer "assists", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "def_votes_count", default: 0, null: false
    t.integer "elo"
    t.integer "goals", default: 0, null: false
    t.integer "mvp_votes_count", default: 0, null: false
    t.decimal "performance_score", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "player_id", null: false
    t.integer "season_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "season_id"], name: "index_player_season_stats_on_player_id_and_season_id", unique: true
    t.index ["player_id"], name: "index_player_season_stats_on_player_id"
    t.index ["season_id", "assists"], name: "index_player_season_stats_on_season_id_and_assists"
    t.index ["season_id", "def_votes_count"], name: "index_player_season_stats_on_season_id_and_def_votes_count"
    t.index ["season_id", "elo"], name: "index_player_season_stats_on_season_id_and_elo"
    t.index ["season_id", "goals"], name: "index_player_season_stats_on_season_id_and_goals"
    t.index ["season_id", "mvp_votes_count"], name: "index_player_season_stats_on_season_id_and_mvp_votes_count"
    t.index ["season_id"], name: "index_player_season_stats_on_season_id"
  end

  create_table "players", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "approval_status", default: "pending", null: false
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.integer "elo"
    t.decimal "global_performance_score", precision: 8, scale: 2, default: "0.0", null: false
    t.string "name", null: false
    t.string "nickname", null: false
    t.string "phone"
    t.string "profile_color_hex"
    t.string "profile_color_key"
    t.string "profile_icon"
    t.datetime "rejected_at"
    t.string "role_code", default: "ANY", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_players_on_active"
    t.index ["approval_status", "active", "name"], name: "index_players_on_approval_status_and_active_and_name"
    t.index ["approval_status"], name: "index_players_on_approval_status"
    t.index ["nickname"], name: "index_players_on_nickname", unique: true
    t.index ["phone"], name: "index_players_on_phone", unique: true
    t.index ["profile_color_key", "profile_icon"], name: "index_players_on_profile_color_key_and_profile_icon"
    t.index ["profile_color_key"], name: "index_players_on_profile_color_key"
    t.index ["profile_icon"], name: "index_players_on_profile_icon"
    t.index ["role_code"], name: "index_players_on_role_code"
  end

  create_table "seasons", force: :cascade do |t|
    t.decimal "assist_points", precision: 6, scale: 2, default: "0.8", null: false
    t.datetime "created_at", null: false
    t.decimal "def_max_points", precision: 6, scale: 2, default: "3.0", null: false
    t.integer "def_vote_bonus", default: 10, null: false
    t.integer "elo_k_factor", default: 32, null: false
    t.decimal "elo_k_value", precision: 6, scale: 2, default: "16.0", null: false
    t.datetime "elo_recalculated_at"
    t.boolean "elo_settings_locked", default: false, null: false
    t.date "ends_on"
    t.integer "expected_voters_count", default: 5, null: false
    t.decimal "goal_points", precision: 6, scale: 2, default: "1.0", null: false
    t.integer "initial_elo", default: 1000, null: false
    t.decimal "mvp_max_points", precision: 6, scale: 2, default: "4.0", null: false
    t.integer "mvp_vote_bonus", default: 10, null: false
    t.string "name", null: false
    t.decimal "player_advantage_elo", precision: 6, scale: 2, default: "40.0", null: false
    t.decimal "season_elo_carryover_factor", precision: 4, scale: 2, default: "0.5", null: false
    t.date "starts_on", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.decimal "voting_bonus_cap", precision: 6, scale: 2, default: "5.0", null: false
    t.index ["name"], name: "index_seasons_on_name", unique: true
    t.index ["starts_on", "ends_on"], name: "index_seasons_on_starts_on_and_ends_on"
    t.index ["status"], name: "index_seasons_on_status"
  end

  create_table "team_players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "elo_after"
    t.integer "elo_before"
    t.integer "elo_delta"
    t.integer "player_id", null: false
    t.string "player_name", null: false
    t.integer "position"
    t.string "role_code", default: "ANY", null: false
    t.integer "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "team_id"], name: "index_team_players_on_player_id_and_team_id"
    t.index ["player_id"], name: "index_team_players_on_player_id"
    t.index ["team_id", "player_id"], name: "index_team_players_on_team_id_and_player_id", unique: true
    t.index ["team_id"], name: "index_team_players_on_team_id"
  end

  create_table "team_setups", force: :cascade do |t|
    t.datetime "accepted_at"
    t.string "algorithm_version"
    t.datetime "created_at", null: false
    t.integer "match_day_id", null: false
    t.integer "reroll_count", default: 0, null: false
    t.string "setup_method"
    t.datetime "updated_at", null: false
    t.index ["match_day_id"], name: "index_team_setups_on_match_day_id"
  end

  create_table "teams", force: :cascade do |t|
    t.integer "captain_id"
    t.datetime "created_at", null: false
    t.integer "elo_after"
    t.integer "elo_before"
    t.integer "elo_delta"
    t.string "lineup_source", default: "manual", null: false
    t.integer "match_id"
    t.string "name", null: false
    t.boolean "playing", default: true, null: false
    t.integer "position"
    t.string "result"
    t.integer "score", default: 0, null: false
    t.integer "source_team_id"
    t.integer "team_setup_id", null: false
    t.string "team_type", null: false
    t.datetime "updated_at", null: false
    t.index ["captain_id"], name: "index_teams_on_captain_id"
    t.index ["match_id", "team_type"], name: "index_teams_on_match_id_and_team_type"
    t.index ["match_id"], name: "index_teams_on_match_id"
    t.index ["source_team_id"], name: "index_teams_on_source_team_id"
    t.index ["team_setup_id"], name: "index_teams_on_team_setup_id"
    t.index ["team_type", "team_setup_id"], name: "index_teams_on_team_type_and_team_setup_id"
    t.index ["team_type"], name: "index_teams_on_team_type"
  end

  add_foreign_key "match_day_players", "match_days"
  add_foreign_key "match_day_players", "players"
  add_foreign_key "match_day_vote_tokens", "match_day_players"
  add_foreign_key "match_day_votes", "match_day_vote_tokens"
  add_foreign_key "match_day_votes", "players", column: "def_player_id"
  add_foreign_key "match_day_votes", "players", column: "mvp_player_id"
  add_foreign_key "match_days", "seasons"
  add_foreign_key "match_goals", "matches"
  add_foreign_key "match_goals", "team_players", column: "assistant_team_player_id"
  add_foreign_key "match_goals", "team_players", column: "scorer_team_player_id"
  add_foreign_key "match_goals", "teams", column: "scoring_team_id"
  add_foreign_key "matches", "match_days"
  add_foreign_key "matches", "matches", column: "lineup_source_match_id"
  add_foreign_key "matches", "team_setups"
  add_foreign_key "matches", "teams", column: "away_team_id"
  add_foreign_key "matches", "teams", column: "home_team_id"
  add_foreign_key "player_rating_changes", "match_days"
  add_foreign_key "player_rating_changes", "matches"
  add_foreign_key "player_rating_changes", "players"
  add_foreign_key "player_rating_changes", "seasons"
  add_foreign_key "player_season_stats", "players"
  add_foreign_key "player_season_stats", "seasons"
  add_foreign_key "team_players", "players"
  add_foreign_key "team_players", "teams"
  add_foreign_key "team_setups", "match_days"
  add_foreign_key "teams", "matches"
  add_foreign_key "teams", "players", column: "captain_id"
  add_foreign_key "teams", "team_setups"
  add_foreign_key "teams", "teams", column: "source_team_id"
end
