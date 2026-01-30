# frozen_string_literal: true

class AddIsDeletedToPlayerRounds < ActiveRecord::Migration[8.1]
  def change
    add_column :player_rounds, :is_deleted, :boolean, default: false, null: false
    add_index :player_rounds, :is_deleted
  end
end
