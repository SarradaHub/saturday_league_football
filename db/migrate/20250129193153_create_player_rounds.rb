class CreatePlayerRounds < ActiveRecord::Migration[8.0]
  def change
    create_table :player_rounds do |t|
      t.references :player, index: true, foreign_key: true
      t.references :round, index: true, foreign_key: true
      t.timestamps
    end
  end
end
