# frozen_string_literal: true

class AddIsDeletedToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :is_deleted, :boolean, default: false, null: false
    add_index :players, :is_deleted
  end
end
