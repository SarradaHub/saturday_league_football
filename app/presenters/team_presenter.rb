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

  private

  def serialized_matches
    matches.map { |match| MatchPresenter.new(match).as_json }
  end

  def serialized_players(options = {})
    # Use PlayerSerializer in nested contexts to avoid circular references and reduce payload
    if options[:use_serializer] || options[:skip_rounds]
      players.map { |player| PlayerSerializer.new(player).as_json }
    else
      players.map { |player| PlayerPresenter.new(player).as_json(skip_rounds: true, skip_player_stats: true) }
    end
  end
end
