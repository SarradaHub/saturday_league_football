# frozen_string_literal: true

class AddDataIntegrityConstraints < ActiveRecord::Migration[8.0]
  def change
    # Use unscoped: models include SoftDeletable (default_scope on is_deleted), but this
    # migration runs before the is_deleted columns are added by later migrations.
    Match.unscoped.where(name: nil).update_all(name: 'Unnamed match')
    Round.unscoped.where(name: nil).update_all(name: 'Unnamed round')
    Player.unscoped.where(name: nil).update_all(name: 'Unnamed player')
    Team.unscoped.where(name: nil).update_all(name: 'Unnamed team')

    change_column_null :matches, :name, false
    change_column_null :rounds, :name, false
    change_column_null :players, :name, false
    change_column_null :teams, :name, false

    add_index :player_stats, %i[match_id player_id], name: 'index_player_stats_on_match_and_player', if_not_exists: true
    add_index :player_stats, %i[match_id team_id], name: 'index_player_stats_on_match_and_team', if_not_exists: true
    add_index :player_rounds, %i[player_id round_id], unique: true, if_not_exists: true
    add_index :player_teams, %i[player_id team_id], unique: true, if_not_exists: true
  end
end
