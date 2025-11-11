# frozen_string_literal: true

class MatchPresenter < ApplicationPresenter
  def as_json(*)
    {
      id: id,
      name: name,
      round_id: round_id,
      team_1: team_1,
      team_2: team_2,
      winning_team: winning_team,
      draw: draw,
      team_1_players: team_players(resource.team_1),
      team_2_players: team_players(resource.team_2),
      statistics: statistics_payload,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  delegate :id, :name, :round_id, :draw, :created_at, :updated_at, to: :resource

  def team_1
    TeamSerializer.new(resource.team_1).as_json
  end

  def team_2
    TeamSerializer.new(resource.team_2).as_json
  end

  def winning_team
    TeamSerializer.new(resource.winning_team).as_json
  end

  def team_1_players
    team_players(resource.team_1)
  end

  def team_2_players
    team_players(resource.team_2)
  end

  def team_1_goals
    statistics.scoreboard[:team_1]
  end

  def team_2_goals
    statistics.scoreboard[:team_2]
  end

  def team_1_goals_scorer
    statistics.breakdown_for(resource.team_1, resource.team_2)[:goal_scorers]
  end

  def team_1_assists
    statistics.breakdown_for(resource.team_1, resource.team_2)[:assists]
  end

  def team_1_own_goals_scorer
    statistics.breakdown_for(resource.team_1, resource.team_2)[:own_goals]
  end

  def team_2_goals_scorer
    statistics.breakdown_for(resource.team_2, resource.team_1)[:goal_scorers]
  end

  def team_2_assists
    statistics.breakdown_for(resource.team_2, resource.team_1)[:assists]
  end

  def team_2_own_goals_scorer
    statistics.breakdown_for(resource.team_2, resource.team_1)[:own_goals]
  end

  private

  def statistics
    @statistics ||= MatchStatisticsPresenter.new(resource)
  end

  def statistics_payload
    {
      team_1: statistics.breakdown_for(resource.team_1, resource.team_2),
      team_2: statistics.breakdown_for(resource.team_2, resource.team_1),
      scoreboard: statistics.scoreboard
    }
  end

  def team_players(team)
    return [] if team.blank?

    team.players.map { |player| PlayerSerializer.new(player).as_json }
  end
end
