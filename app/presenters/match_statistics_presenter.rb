# frozen_string_literal: true

class MatchStatisticsPresenter < ApplicationPresenter
  def scoreboard
    {
      team_1: goals_for(resource.team_1, resource.team_2),
      team_2: goals_for(resource.team_2, resource.team_1)
    }
  end

  def breakdown_for(team, opponent)
    {
      goals: goals_for(team, opponent),
      goal_scorers: grouped_totals(team, :goals),
      assists: grouped_totals(team, :assists),
      own_goals: grouped_totals(team, :own_goals)
    }
  end

  private

  def goals_for(team, opponent)
    return 0 if team.blank?

    team_stats(team).sum(&:goals) + own_goals_from(opponent)
  end

  def own_goals_from(team)
    return 0 if team.blank?

    team_stats(team).sum(&:own_goals)
  end

  def grouped_totals(team, attribute)
    return {} if team.blank?

    team_stats(team)
      .select { |stat| stat.public_send(attribute).to_i.positive? }
      .group_by { |stat| stat.player.name }
      .transform_values { |stats| stats.sum { |stat| stat.public_send(attribute).to_i } }
  end

  def team_stats(team)
    @team_stats ||= {}
    @team_stats[team.id] ||= Matches::PlayerStatsQuery.call(match: resource, team: team)
  end
end
