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

ActiveRecord::Schema[8.1].define(version: 2026_01_28_215209) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "championships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.boolean "is_deleted", default: false, null: false
    t.integer "max_players_per_team", null: false
    t.integer "min_players_per_team", null: false
    t.string "name", null: false
    t.integer "players_count", default: 0, null: false
    t.integer "rounds_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["is_deleted"], name: "index_championships_on_is_deleted"
    t.index ["players_count"], name: "index_championships_on_players_count"
    t.index ["rounds_count"], name: "index_championships_on_rounds_count"
    t.index ["updated_at"], name: "index_championships_on_updated_at"
    t.index ["user_id"], name: "index_championships_on_user_id"
  end

  create_table "matches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "draw"
    t.boolean "is_deleted", default: false, null: false
    t.string "name", null: false
    t.bigint "round_id"
    t.bigint "team_1_id"
    t.bigint "team_2_id"
    t.datetime "updated_at", null: false
    t.bigint "winning_team_id"
    t.index ["created_at"], name: "index_matches_on_created_at"
    t.index ["is_deleted"], name: "index_matches_on_is_deleted"
    t.index ["round_id", "team_1_id"], name: "index_matches_on_round_id_and_team_1_id"
    t.index ["round_id", "team_2_id"], name: "index_matches_on_round_id_and_team_2_id"
    t.index ["round_id"], name: "index_matches_on_round_id"
    t.index ["team_1_id"], name: "index_matches_on_team_1_id"
    t.index ["team_2_id"], name: "index_matches_on_team_2_id"
    t.index ["winning_team_id"], name: "index_matches_on_winning_team_id"
  end

  create_table "player_rounds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_deleted", default: false, null: false
    t.bigint "player_id"
    t.bigint "round_id"
    t.datetime "updated_at", null: false
    t.index ["is_deleted"], name: "index_player_rounds_on_is_deleted"
    t.index ["player_id", "round_id"], name: "index_player_rounds_on_player_id_and_round_id", unique: true
    t.index ["player_id"], name: "index_player_rounds_on_player_id"
    t.index ["round_id"], name: "index_player_rounds_on_round_id"
  end

  create_table "player_stats", force: :cascade do |t|
    t.integer "assists"
    t.datetime "created_at", null: false
    t.integer "goals"
    t.boolean "is_deleted", default: false, null: false
    t.bigint "match_id"
    t.integer "own_goals"
    t.bigint "player_id"
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.boolean "was_goalkeeper"
    t.index ["is_deleted"], name: "index_player_stats_on_is_deleted"
    t.index ["match_id", "player_id"], name: "index_player_stats_on_match_and_player"
    t.index ["match_id", "team_id"], name: "index_player_stats_on_match_and_team"
    t.index ["match_id"], name: "index_player_stats_on_match_id"
    t.index ["player_id"], name: "index_player_stats_on_player_id"
    t.index ["team_id"], name: "index_player_stats_on_team_id"
  end

  create_table "player_teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_deleted", default: false, null: false
    t.bigint "player_id"
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.index ["is_deleted"], name: "index_player_teams_on_is_deleted"
    t.index ["player_id", "team_id"], name: "index_player_teams_on_player_id_and_team_id", unique: true
    t.index ["player_id"], name: "index_player_teams_on_player_id"
    t.index ["team_id"], name: "index_player_teams_on_team_id"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_deleted", default: false, null: false
    t.string "name", null: false
    t.integer "player_stats_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["is_deleted"], name: "index_players_on_is_deleted"
    t.index ["name"], name: "index_players_on_name"
    t.index ["player_stats_count"], name: "index_players_on_player_stats_count"
  end

  create_table "rounds", force: :cascade do |t|
    t.bigint "championship_id"
    t.datetime "created_at", null: false
    t.boolean "is_deleted", default: false, null: false
    t.integer "matches_count", default: 0, null: false
    t.string "name", null: false
    t.integer "players_count", default: 0, null: false
    t.date "round_date"
    t.datetime "updated_at", null: false
    t.index ["championship_id"], name: "index_rounds_on_championship_id"
    t.index ["is_deleted"], name: "index_rounds_on_is_deleted"
    t.index ["matches_count"], name: "index_rounds_on_matches_count"
    t.index ["players_count"], name: "index_rounds_on_players_count"
    t.index ["round_date"], name: "index_rounds_on_round_date"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_deleted", default: false, null: false
    t.string "name", null: false
    t.integer "players_count", default: 0, null: false
    t.bigint "round_id"
    t.datetime "updated_at", null: false
    t.index ["is_deleted"], name: "index_teams_on_is_deleted"
    t.index ["name"], name: "index_teams_on_name"
    t.index ["players_count"], name: "index_teams_on_players_count"
    t.index ["round_id"], name: "index_teams_on_round_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "external_id"
    t.boolean "is_admin", default: false, null: false
    t.boolean "is_deleted", default: false, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["external_id"], name: "index_users_on_external_id", unique: true
    t.index ["is_admin"], name: "index_users_on_is_admin"
    t.index ["is_deleted"], name: "index_users_on_is_deleted"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "championships", "users"
  add_foreign_key "matches", "rounds"
  add_foreign_key "matches", "teams", column: "team_1_id"
  add_foreign_key "matches", "teams", column: "team_2_id"
  add_foreign_key "matches", "teams", column: "winning_team_id"
  add_foreign_key "player_rounds", "players"
  add_foreign_key "player_rounds", "rounds"
  add_foreign_key "player_stats", "matches"
  add_foreign_key "player_stats", "players"
  add_foreign_key "player_stats", "teams"
  add_foreign_key "player_teams", "players"
  add_foreign_key "player_teams", "teams"
  add_foreign_key "rounds", "championships"
  add_foreign_key "teams", "rounds"
end
