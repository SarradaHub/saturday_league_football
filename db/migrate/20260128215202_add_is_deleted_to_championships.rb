# frozen_string_literal: true

class AddIsDeletedToChampionships < ActiveRecord::Migration[8.1]
  def change
    add_column :championships, :is_deleted, :boolean, default: false, null: false
    add_index :championships, :is_deleted
  end
end
