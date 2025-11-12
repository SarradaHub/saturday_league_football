class AddPlayerLimitsToChampionships < ActiveRecord::Migration[8.0]
  def up
    add_column :championships, :min_players_per_team, :integer, null: false, default: 0
    add_column :championships, :max_players_per_team, :integer, null: false, default: 0

    execute <<~SQL.squish
      UPDATE championships
      SET min_players_per_team = 5, max_players_per_team = 12
      WHERE min_players_per_team = 0 AND max_players_per_team = 0
    SQL

    change_column_default :championships, :min_players_per_team, nil
    change_column_default :championships, :max_players_per_team, nil
  end

  def down
    remove_column :championships, :min_players_per_team
    remove_column :championships, :max_players_per_team
  end
end
