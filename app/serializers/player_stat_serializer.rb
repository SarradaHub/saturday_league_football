# frozen_string_literal: true

class PlayerStatSerializer < ApplicationSerializer
  def as_json(*)
    {
      id: resource.id,
      goals: resource.goals,
      own_goals: resource.own_goals,
      assists: resource.assists,
      was_goalkeeper: resource.was_goalkeeper,
      match_id: resource.match_id,
      team_id: resource.team_id,
      player_id: resource.player_id,
      created_at: resource.created_at,
      updated_at: resource.updated_at
    }
  end
end
