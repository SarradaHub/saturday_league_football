# frozen_string_literal: true

class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    # Index for ordering rounds by round_date (frequently used in queries)
    add_index :rounds, :round_date unless index_exists?(:rounds, :round_date)

    # Index for ordering championships by updated_at (used in CollectionQuery)
    add_index :championships, :updated_at unless index_exists?(:championships, :updated_at)

    # Index for ordering matches by created_at (used in CollectionQuery)
    add_index :matches, :created_at unless index_exists?(:matches, :created_at)

    # Composite index for matches filtered by round and team (common query pattern)
    # This helps with queries like: Match.where(round_id: X).where('team_1_id = ? OR team_2_id = ?', team_id, team_id)
    add_index :matches, [:round_id, :team_1_id], name: 'index_matches_on_round_id_and_team_1_id' unless index_exists?(:matches, [:round_id, :team_1_id], name: 'index_matches_on_round_id_and_team_1_id')
    add_index :matches, [:round_id, :team_2_id], name: 'index_matches_on_round_id_and_team_2_id' unless index_exists?(:matches, [:round_id, :team_2_id], name: 'index_matches_on_round_id_and_team_2_id')

    # Index for ordering players by name (used in CollectionQuery)
    add_index :players, :name unless index_exists?(:players, :name)

    # Index for ordering teams by name (used in CollectionQuery)
    add_index :teams, :name unless index_exists?(:teams, :name)
  end
end
