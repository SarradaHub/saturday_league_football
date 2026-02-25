# frozen_string_literal: true

class TeamPresenter < ApplicationPresenter
  delegate :id, :name, :round_id, :created_at, :updated_at, :is_blocked, to: :resource

  def as_json(options = {})
    result = {
      id: id,
      name: name,
      round_id: round_id,
      is_blocked: is_blocked,
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
    # Include player_team_id and inscription_order (1-based) so the frontend can show order in team.
    if options[:use_serializer] || options[:skip_rounds]
      player_teams_ordered.each_with_index.map do |pt, idx|
        PlayerSerializer.new(pt.player).as_json.merge(player_team_id: pt.id, inscription_order: idx + 1)
      end
    else
      player_teams_ordered.each_with_index.map do |pt, idx|
        PlayerPresenter.new(pt.player).as_json(skip_rounds: true, skip_player_stats: true).merge(player_team_id: pt.id, inscription_order: idx + 1)
      end
    end
  end
end
