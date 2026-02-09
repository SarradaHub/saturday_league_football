# frozen_string_literal: true

class AddBlockedToPlayerRounds < ActiveRecord::Migration[8.1]
  def change
    add_column :player_rounds, :blocked, :boolean, default: false, null: false
    add_index :player_rounds, :blocked
  end
end
