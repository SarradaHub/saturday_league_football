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

    if team.association(:players).loaded?
      team.players.map { |player| PlayerSerializer.new(player).as_json }
    else
      team.players.load.map { |player| PlayerSerializer.new(player).as_json }
    end
  end

  def hash_to_player_array(team, hash)
    return [] if hash.blank? || !hash.is_a?(Hash)

    result = []
    hash.each do |player_name, count|
      player = find_player_by_name(team, player_name)
      next unless player

      count.to_i.times do
        result << PlayerSerializer.new(player).as_json
      end
    end
    result
  end

  def find_player_by_name(team, name)
    return nil if team.blank? || name.blank?

    team.players.find { |p| p.display_name == name.to_s }
  end

  def team_1_goals_scorer_array
    hash_to_player_array(resource.team_1, team_1_goals_scorer)
  end

  def team_1_assists_array
    hash_to_player_array(resource.team_1, team_1_assists)
  end

  def team_1_own_goals_scorer_array
    # Own goals from team_2 count for team_1
    hash_to_player_array(resource.team_2, statistics.breakdown_for(resource.team_2, resource.team_1)[:own_goals])
  end

  def team_2_goals_scorer_array
    hash_to_player_array(resource.team_2, team_2_goals_scorer)
  end

  def team_2_assists_array
    hash_to_player_array(resource.team_2, team_2_assists)
  end

  def team_2_own_goals_scorer_array
    # Own goals from team_1 count for team_2
    hash_to_player_array(resource.team_1, statistics.breakdown_for(resource.team_1, resource.team_2)[:own_goals])
  end

  def team_1_goalkeepers_array
    goalkeepers_to_player_array(resource.team_1, team_1_goalkeepers)
  end

  def team_2_goalkeepers_array
    goalkeepers_to_player_array(resource.team_2, team_2_goalkeepers)
  end

  def goalkeepers_to_player_array(team, goalkeeper_names)
    return [] if team.blank? || goalkeeper_names.blank? || !goalkeeper_names.is_a?(Array)

    result = []
    goalkeeper_names.each do |player_name|
      player = find_player_by_name(team, player_name)
      result << PlayerSerializer.new(player).as_json if player
    end
    result
  end
end
