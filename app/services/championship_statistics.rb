# frozen_string_literal: true

class ChampionshipStatistics < ApplicationService
  def initialize(championship_id:)
    @championship_id = championship_id
  end

  def call
    championship = Championship.find(championship_id)
    rounds = championship.rounds.includes(:matches, :player_rounds)
    match_ids = rounds.flat_map { |r| r.matches.pluck(:id) }.uniq
    player_ids = rounds.flat_map { |r| r.player_rounds.pluck(:player_id) }.uniq

    return {} if match_ids.empty? || player_ids.empty?

    player_stats = PlayerStat.where(match_id: match_ids, player_id: player_ids)
    matches = Match.where(id: match_ids).includes(:team_1, :team_2)

    stats_by_player = {}
    player_ids.each do |player_id|
      player = Player.find(player_id)
      stats = player_stats.where(player_id: player_id)

      wins, losses, draws = calculate_match_results(player_id, matches, stats)

      stats_by_player[player_id] = {
        player: {
          id: player.id,
          display_name: player.display_name
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

  attr_reader :championship_id

  def calculate_match_results(player_id, matches, player_stats)
    wins = 0
    losses = 0
    draws = 0

    matches.each do |match|
      stat = player_stats.find { |ps| ps.match_id == match.id }
      next unless stat

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
