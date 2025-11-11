# frozen_string_literal: true

class RoundPresenter < ApplicationPresenter
  delegate :id, :name, :round_date, :championship_id, :created_at, :updated_at, to: :resource

  def as_json(*)
    {
      id: id,
      name: name,
      round_date: round_date,
      championship_id: championship_id,
      created_at: created_at,
      updated_at: updated_at,
      matches: serialized_matches,
      players: serialized_players,
      teams: serialized_teams
    }
  end

  def matches
    resource.matches
  end

  def players
    resource.players.distinct
  end

  def teams
    resource.teams.distinct
  end

  private

  def serialized_matches
    matches.map { |match| MatchPresenter.new(match).as_json }
  end

  def serialized_players
    players.map { |player| PlayerPresenter.new(player).as_json }
  end

  def serialized_teams
    teams.map { |team| TeamPresenter.new(team).as_json }
  end
end
