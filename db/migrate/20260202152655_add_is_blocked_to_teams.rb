# frozen_string_literal: true

class AddIsBlockedToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :is_blocked, :boolean, default: false, null: false
    add_index :teams, :is_blocked
  end
end
