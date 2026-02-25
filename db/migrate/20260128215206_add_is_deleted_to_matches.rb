# frozen_string_literal: true

class AddIsDeletedToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :is_deleted, :boolean, default: false, null: false
    add_index :matches, :is_deleted
  end
end
