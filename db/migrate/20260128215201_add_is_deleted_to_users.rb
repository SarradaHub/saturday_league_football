# frozen_string_literal: true

class AddIsDeletedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :is_deleted, :boolean, default: false, null: false
    add_index :users, :is_deleted
  end
end
