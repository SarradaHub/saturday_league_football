# frozen_string_literal: true

class AddIsDeletedToPlayerStats < ActiveRecord::Migration[8.1]
  def change
    add_column :player_stats, :is_deleted, :boolean, default: false, null: false
    add_index :player_stats, :is_deleted
  end
end
