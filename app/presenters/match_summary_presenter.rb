# frozen_string_literal: true

class MatchSummaryPresenter < ApplicationPresenter
  delegate :id, :name, :round_id, :team_1_id, :team_2_id, :winning_team_id, :draw, :created_at, to: :resource

  def as_json(*)
    {
      id: id,
      name: name,
      round_id: round_id,
      team_1_id: team_1_id,
      team_2_id: team_2_id,
      winning_team_id: winning_team_id,
      draw: draw,
      team_1_goals: team_1_goals,
      team_2_goals: team_2_goals,
      team_1_name: team_1_name,
      team_2_name: team_2_name,
      created_at: created_at
    }
  end

  private

  def team_1_goals
    calculate_goals_for(resource.team_1_id, resource.team_2_id)
  end

  def team_2_goals
    calculate_goals_for(resource.team_2_id, resource.team_1_id)
  end

  def calculate_goals_for(team_id, opponent_id)
    return 0 if team_id.blank?

    team_goals = PlayerStat.where(match_id: resource.id, team_id: team_id).sum(:goals)
    opponent_own_goals = if opponent_id.blank?
                           0
    else
                           PlayerStat.where(match_id: resource.id, team_id: opponent_id).sum(:own_goals)
    end
    team_goals + opponent_own_goals
  end

  def team_1_name
    resource.team_1&.name
  end

  def team_2_name
    resource.team_2&.name
  end
end
