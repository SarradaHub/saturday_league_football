# frozen_string_literal: true

class AddIsDeletedToPlayerTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :player_teams, :is_deleted, :boolean, default: false, null: false
    add_index :player_teams, :is_deleted
  end
end
