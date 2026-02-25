# frozen_string_literal: true

class AddIsDeletedToRounds < ActiveRecord::Migration[8.1]
  def change
    add_column :rounds, :is_deleted, :boolean, default: false, null: false
    add_index :rounds, :is_deleted
  end
end
