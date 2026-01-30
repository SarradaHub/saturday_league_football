# frozen_string_literal: true

class AddCounterCacheColumns < ActiveRecord::Migration[8.1]
  def change
    # Add rounds_count to championships
    add_column :championships, :rounds_count, :integer, default: 0, null: false

    # Add players_count to championships (distinct count - will be managed by callbacks)
    add_column :championships, :players_count, :integer, default: 0, null: false

    # Add matches_count to rounds
    add_column :rounds, :matches_count, :integer, default: 0, null: false

    # Add players_count to rounds (via player_rounds)
    add_column :rounds, :players_count, :integer, default: 0, null: false

    # Add players_count to teams (via player_teams)
    add_column :teams, :players_count, :integer, default: 0, null: false

    # Add player_stats_count to players
    add_column :players, :player_stats_count, :integer, default: 0, null: false

    # Add indexes for performance
    add_index :championships, :rounds_count
    add_index :championships, :players_count
    add_index :rounds, :matches_count
    add_index :rounds, :players_count
    add_index :teams, :players_count
    add_index :players, :player_stats_count
  end
end
