# frozen_string_literal: true

class AddGoalkeeperOnlyToPlayerRounds < ActiveRecord::Migration[8.1]
  def change
    add_column :player_rounds, :goalkeeper_only, :boolean, default: false, null: false
    add_index :player_rounds, :goalkeeper_only
  end
end
