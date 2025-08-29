# frozen_string_literal: true

class Match < ApplicationRecord
  belongs_to :round
  belongs_to :team_1, class_name: 'Team', foreign_key: 'team_1_id'
  belongs_to :team_2, class_name: 'Team', foreign_key: 'team_2_id'
  belongs_to :winning_team, class_name: 'Team', foreign_key: 'winning_team_id', optional: true

  validates :name, presence: true

  def team_goals(team, opposing_team)
    goals = player_stats_for_team(team).sum(&:goals)
    own_goals = player_stats_for_team(opposing_team).sum(&:own_goals)
    goals + own_goals
  end

  def goals_scorers_with_count(team)
    player_stats_for_team(team)
      .select { |stat| stat.goals.positive? }
      .group_by { |stat| stat.player.name }
      .transform_values { |stats| stats.sum(&:goals) }
  end

  def assists_with_count(team)
    player_stats_for_team(team)
      .select { |stat| stat.goals.positive? }
      .group_by { |stat| stat.player.name }
      .transform_values { |stats| stats.sum(&:assists) }
  end

  def own_goals_scorers_with_count(team)
    player_stats_for_team(team)
      .select { |stat| stat.own_goals.positive? }
      .group_by { |stat| stat.player.name }
      .transform_values { |stats| stats.sum(&:own_goals) }
  end

  def team_1_goals
    team_goals(team_1, team_2)
  end

  def team_1_goals_scorer
    goals_scorers_with_count(team_1)
  end

  def team_1_assists
    assists_with_count(team_1)
  end

  def team_1_own_goals_scorer
    own_goals_scorers_with_count(team_1)
  end

  def team_2_goals
    team_goals(team_2, team_1)
  end

  def team_2_goals_scorer
    goals_scorers_with_count(team_2)
  end

  def team_2_assists
    assists_with_count(team_2)
  end

  def team_2_own_goals_scorer
    own_goals_scorers_with_count(team_2)
  end

  private

  def player_stats_for_team(team)
    team.players.includes(:player_stats).flat_map(&:player_stats)
        .select { |stat| stat.match_id == id }
  end
end
