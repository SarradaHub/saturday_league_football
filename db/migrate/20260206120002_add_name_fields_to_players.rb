# frozen_string_literal: true

class AddNameFieldsToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :first_name, :string
    add_column :players, :last_name, :string
    add_column :players, :nickname, :string
    add_index :players, :first_name
    add_index :players, :last_name
    add_index :players, :nickname
  end
end
