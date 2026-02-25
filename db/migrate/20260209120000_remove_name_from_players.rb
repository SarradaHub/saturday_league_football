# frozen_string_literal: true

class RemoveNameFromPlayers < ActiveRecord::Migration[8.1]
  def up
    # Backfill first_name from name where both first_name and last_name are blank
    Player.reset_column_information
    Player.unscoped.where(first_name: [nil, ""]).where(last_name: [nil, ""]).find_each do |p|
      next if p.read_attribute_before_type_cast(:name).to_s.strip.blank?
      name_val = p.read_attribute_before_type_cast(:name).to_s.strip
      parts = name_val.split(/\s+/, 2)
      p.update_columns(first_name: parts[0], last_name: parts[1].to_s)
    end

    remove_index :players, name: "index_players_on_name" if index_exists?(:players, :name, name: "index_players_on_name")
    remove_column :players, :name
  end

  def down
    add_column :players, :name, :string
    add_index :players, :name, name: "index_players_on_name"
    Player.reset_column_information
    Player.unscoped.find_each do |p|
      full = [p.first_name, p.last_name].compact.join(" ").strip
      p.update_column(:name, full.presence || "—")
    end
  end
end
