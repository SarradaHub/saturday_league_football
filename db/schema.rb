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

ActiveRecord::Schema[8.1].define(version: 2025_11_11_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "championships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.integer "max_players_per_team", null: false
    t.integer "min_players_per_team", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "matches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "draw"
    t.string "name", null: false
    t.bigint "round_id"
    t.bigint "team_1_id"
    t.bigint "team_2_id"
    t.datetime "updated_at", null: false
    t.bigint "winning_team_id"
    t.index ["round_id"], name: "index_matches_on_round_id"
    t.index ["team_1_id"], name: "index_matches_on_team_1_id"
    t.index ["team_2_id"], name: "index_matches_on_team_2_id"
    t.index ["winning_team_id"], name: "index_matches_on_winning_team_id"
  end

  create_table "player_rounds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "player_id"
    t.bigint "round_id"
    t.datetime "updated_at", null: false
    t.index ["player_id", "round_id"], name: "index_player_rounds_on_player_id_and_round_id", unique: true
    t.index ["player_id"], name: "index_player_rounds_on_player_id"
    t.index ["round_id"], name: "index_player_rounds_on_round_id"
  end

  create_table "player_stats", force: :cascade do |t|
    t.integer "assists"
    t.datetime "created_at", null: false
    t.integer "goals"
    t.bigint "match_id"
    t.integer "own_goals"
    t.bigint "player_id"
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.boolean "was_goalkeeper"
    t.index ["match_id", "player_id"], name: "index_player_stats_on_match_and_player"
    t.index ["match_id", "team_id"], name: "index_player_stats_on_match_and_team"
    t.index ["match_id"], name: "index_player_stats_on_match_id"
    t.index ["player_id"], name: "index_player_stats_on_player_id"
    t.index ["team_id"], name: "index_player_stats_on_team_id"
  end

  create_table "player_teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "player_id"
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.index ["player_id", "team_id"], name: "index_player_teams_on_player_id_and_team_id", unique: true
    t.index ["player_id"], name: "index_player_teams_on_player_id"
    t.index ["team_id"], name: "index_player_teams_on_team_id"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "rounds", force: :cascade do |t|
    t.bigint "championship_id"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.date "round_date"
    t.datetime "updated_at", null: false
    t.index ["championship_id"], name: "index_rounds_on_championship_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "round_id"
    t.datetime "updated_at", null: false
    t.index ["round_id"], name: "index_teams_on_round_id"
  end

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
