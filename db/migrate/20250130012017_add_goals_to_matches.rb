class AddGoalsToMatches < ActiveRecord::Migration[8.0]
  def change
    add_column :matches, :team_1_goals, :integer
    add_column :matches, :team_2_goals, :integer
  end
end
