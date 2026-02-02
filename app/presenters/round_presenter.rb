# frozen_string_literal: true

class RoundPresenter < ApplicationPresenter
  delegate :id, :name, :round_date, :championship_id, :created_at, :updated_at, to: :resource

  def as_json(options = {})
    result = {
      id: id,
      name: name,
      round_date: round_date,
      championship_id: championship_id,
      created_at: created_at,
      updated_at: updated_at
    }

    # Only serialize nested data if not explicitly skipped (for list views)
    unless options[:skip_nested]
      result[:matches] = serialized_matches
      result[:players] = serialized_players
      result[:teams] = serialized_teams
    end

    result
  end

  def matches
    resource.matches
  end

  def matches_count
    resource.matches_count || resource.matches.count
  end

  def players
    resource.players.distinct
  end

  def players_count
    resource.players_count || resource.players.distinct.count
  end

  def teams
    resource.teams.distinct
  end

  private

  def serialized_matches
    matches.map { |match| MatchPresenter.new(match).as_json }
  end

  def serialized_players
    # Use PlayerSerializer to avoid circular reference (players -> rounds -> players)
    # RoundPresenter already provides rounds, so we don't need rounds in each player
    players.map { |player| PlayerSerializer.new(player).as_json }
  end

  def serialized_teams
    teams.map { |team| TeamPresenter.new(team).as_json(skip_matches: true) }
  end
end
