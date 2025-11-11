# frozen_string_literal: true

class TeamPresenter < ApplicationPresenter
  delegate :id, :name, :round_id, :created_at, :updated_at, to: :resource

  def as_json(*)
    {
      id: id,
      name: name,
      round_id: round_id,
      created_at: created_at,
      updated_at: updated_at,
      matches: serialized_matches,
      players: serialized_players
    }
  end

  def matches
    Teams::MatchesQuery.call(team: resource)
  end

  def players
    resource.players.distinct
  end

  private

  def serialized_matches
    matches.map { |match| MatchPresenter.new(match).as_json }
  end

  def serialized_players
    players.map { |player| PlayerPresenter.new(player).as_json }
  end
end
