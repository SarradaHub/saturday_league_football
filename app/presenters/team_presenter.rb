# frozen_string_literal: true

class TeamPresenter < ApplicationPresenter
  delegate :id, :name, :round_id, :created_at, :updated_at, to: :resource

  def as_json(options = {})
    result = {
      id: id,
      name: name,
      round_id: round_id,
      created_at: created_at,
      updated_at: updated_at,
      players: serialized_players(options)
    }

    # Only serialize matches if not explicitly skipped (prevents circular reference in round context)
    result[:matches] = serialized_matches unless options[:skip_matches]

    result
  end

  def matches
    Teams::MatchesQuery.call(team: resource)
  end

  def players
    resource.player_teams.includes(:player).order(:created_at).map(&:player)
  end

  def player_teams_ordered
    resource.player_teams.includes(:player).order(:created_at)
  end

  private

  def serialized_matches
    matches.map { |match| MatchPresenter.new(match).as_json }
  end

  def serialized_players(options = {})
    # Include player_team_id so the frontend can remove a player via nested attributes (_destroy)
    if options[:use_serializer] || options[:skip_rounds]
      player_teams_ordered.map do |pt|
        PlayerSerializer.new(pt.player).as_json.merge(player_team_id: pt.id)
      end
    else
      player_teams_ordered.map do |pt|
        PlayerPresenter.new(pt.player).as_json(skip_rounds: true, skip_player_stats: true).merge(player_team_id: pt.id)
      end
    end
  end
end
