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
      team_1_goals: team_1_goals,
      team_2_goals: team_2_goals,
      team_1_goals_scorer: team_1_goals_scorer_array,
      team_1_assists: team_1_assists_array,
      team_1_own_goals_scorer: team_1_own_goals_scorer_array,
      team_1_goalkeepers: team_1_goalkeepers_array,
      team_2_goals_scorer: team_2_goals_scorer_array,
      team_2_assists: team_2_assists_array,
      team_2_own_goals_scorer: team_2_own_goals_scorer_array,
      team_2_goalkeepers: team_2_goalkeepers_array,
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

  def team_1_goalkeepers
    statistics.breakdown_for(resource.team_1, resource.team_2)[:goalkeepers]
  end

  def team_2_goalkeepers
    statistics.breakdown_for(resource.team_2, resource.team_1)[:goalkeepers]
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

    team.player_teams.includes(:player).order(created_at: :asc).each_with_index.map do |pt, idx|
      PlayerSerializer.new(pt.player).as_json.merge(inscription_order: idx + 1)
    end
  end

  def team_1_goals_scorer_array
    stats_to_player_array(statistics.goal_scorers_with_players(resource.team_1))
  end

  def team_1_assists_array
    stats_to_player_array(statistics.assists_with_players(resource.team_1))
  end

  def team_1_own_goals_scorer_array
    # Own goals from team_2 count for team_1
    stats_to_player_array(statistics.own_goals_scorers_with_players(resource.team_2))
  end

  def team_2_goals_scorer_array
    stats_to_player_array(statistics.goal_scorers_with_players(resource.team_2))
  end

  def team_2_assists_array
    stats_to_player_array(statistics.assists_with_players(resource.team_2))
  end

  def team_2_own_goals_scorer_array
    # Own goals from team_1 count for team_2
    stats_to_player_array(statistics.own_goals_scorers_with_players(resource.team_1))
  end

  def team_1_goalkeepers_array
    statistics.goalkeepers_with_players(resource.team_1).map { |player| PlayerSerializer.new(player).as_json }
  end

  def team_2_goalkeepers_array
    statistics.goalkeepers_with_players(resource.team_2).map { |player| PlayerSerializer.new(player).as_json }
  end

  # Build array of serialized players from stats: [[player, count], ...] -> count copies of each player.
  def stats_to_player_array(player_count_pairs)
    return [] if player_count_pairs.blank?

    result = []
    player_count_pairs.each do |player, count|
      count.to_i.times { result << PlayerSerializer.new(player).as_json }
    end
    result
  end
end
