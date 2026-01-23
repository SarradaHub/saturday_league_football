# frozen_string_literal: true

class RoundStatistics < ApplicationService
  def initialize(round_id:)
    @round_id = round_id
  end

  def call
    round = Round.find(round_id)
    matches = round.matches.includes(:team_1, :team_2)
    player_ids = round.player_rounds.pluck(:player_id).uniq

    return {} if player_ids.empty?

    # Get all player stats for matches in this round
    match_ids = matches.pluck(:id)
    player_stats = PlayerStat.where(match_id: match_ids, player_id: player_ids)

    # Aggregate stats by player
    stats_by_player = {}
    player_ids.each do |player_id|
      player = Player.find(player_id)
      stats = player_stats.where(player_id: player_id)

      # Calculate wins, losses, draws
      wins, losses, draws = calculate_match_results(player_id, matches, stats)

      stats_by_player[player_id] = {
        player: {
          id: player.id,
          name: player.name
        },
        goals: stats.sum(:goals),
        assists: stats.sum(:assists),
        own_goals: stats.sum(:own_goals),
        matches: stats.select(:match_id).distinct.count,
        goalkeeper_count: stats.where(was_goalkeeper: true).count,
        wins: wins,
        losses: losses,
        draws: draws
      }
    end

    stats_by_player
  end

  private

  attr_reader :round_id

  def calculate_match_results(player_id, matches, player_stats)
    wins = 0
    losses = 0
    draws = 0

    matches.each do |match|
      # Check if player participated in this match
      stat = player_stats.find { |ps| ps.match_id == match.id }
      next unless stat

      # Determine result for player's team
      if match.draw
        draws += 1
      elsif match.winning_team_id == stat.team_id
        wins += 1
      else
        losses += 1
      end
    end

    [wins, losses, draws]
  end
end
