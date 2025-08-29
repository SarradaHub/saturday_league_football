class AddRoundIdToTeams < ActiveRecord::Migration[8.0]
  def change
    add_reference :teams, :round, foreign_key: true
  end
end
