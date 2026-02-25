# frozen_string_literal: true

class AddIsDeletedToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :is_deleted, :boolean, default: false, null: false
    add_index :teams, :is_deleted
  end
end
