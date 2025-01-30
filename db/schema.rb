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

ActiveRecord::Schema[8.0].define(version: 2025_01_30_012017) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "championships", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "description"
  end

  create_table "matches", force: :cascade do |t|
    t.string "name"
    t.bigint "round_id"
    t.bigint "team_1_id"
    t.bigint "team_2_id"
    t.bigint "winning_team_id"
    t.boolean "draw"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "team_1_goals"
    t.integer "team_2_goals"
    t.index ["round_id"], name: "index_matches_on_round_id"
    t.index ["team_1_id"], name: "index_matches_on_team_1_id"
    t.index ["team_2_id"], name: "index_matches_on_team_2_id"
    t.index ["winning_team_id"], name: "index_matches_on_winning_team_id"
  end

  create_table "player_rounds", force: :cascade do |t|
    t.bigint "player_id"
    t.bigint "round_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_player_rounds_on_player_id"
    t.index ["round_id"], name: "index_player_rounds_on_round_id"
  end

  create_table "player_stats", force: :cascade do |t|
    t.integer "goals"
    t.integer "own_goals"
    t.integer "assists"
    t.boolean "was_goalkeeper"
    t.bigint "player_id"
    t.bigint "team_id"
    t.bigint "match_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_player_stats_on_match_id"
    t.index ["player_id"], name: "index_player_stats_on_player_id"
    t.index ["team_id"], name: "index_player_stats_on_team_id"
  end

  create_table "player_teams", force: :cascade do |t|
    t.bigint "player_id"
    t.bigint "team_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_player_teams_on_player_id"
    t.index ["team_id"], name: "index_player_teams_on_team_id"
  end

  create_table "players", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "rounds", force: :cascade do |t|
    t.string "name"
    t.date "round_date"
    t.bigint "championship_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["championship_id"], name: "index_rounds_on_championship_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
end
