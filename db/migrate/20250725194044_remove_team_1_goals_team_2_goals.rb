class RemoveTeam1GoalsTeam2Goals < ActiveRecord::Migration[8.0]
  def change
    remove_column :matches, :team_1_goals
    remove_column :matches, :team_2_goals
  end
end
