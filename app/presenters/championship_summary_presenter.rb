# frozen_string_literal: true

class ChampionshipSummaryPresenter < ApplicationPresenter
  delegate :id, :name, :min_players_per_team, :max_players_per_team, :created_at, to: :resource

  def as_json(*)
    {
      id: id,
      name: name,
      min_players_per_team: min_players_per_team,
      max_players_per_team: max_players_per_team,
      rounds_count: rounds_count,
      players_count: players_count,
      created_at: created_at
    }
  end

  private

  def rounds_count
    resource.rounds_count || 0
  end

  def players_count
    resource.players_count || 0
  end
end
