# frozen_string_literal: true

class RoundTeamGenerator
  DEFAULT_TEAM_COUNT = 2

  class PlayerLimitError < StandardError; end

  def self.call(round, team_count: nil)
    new(round, team_count:).call
  end

  def initialize(round, team_count: nil)
    @round = round
    @team_count = team_count || [round.teams.count, DEFAULT_TEAM_COUNT].max
  end

  def call
    return if round.blank?

    players = ordered_players
    adjust_team_count_for_max_limit(players.size)

    ActiveRecord::Base.transaction do
      ensure_minimum_teams(players.any?)
      clear_memberships
      distribute_players(players)
    end
  end

  private

  attr_reader :round, :team_count

  def ordered_players
    round.player_rounds.includes(:player).order(:created_at).map(&:player)
  end

  def ensure_minimum_teams(players_present)
    return unless players_present

    missing = team_count - round.teams.count
    return if missing <= 0

    existing_names = round.teams.pluck(:name)
    missing.times do
      index = existing_names.length + 1
      name = unique_team_name(index, existing_names)
      round.teams.create!(name:)
      existing_names << name
    end
  end

  def clear_memberships
    PlayerTeam.where(team_id: round.teams.select(:id)).delete_all
  end

  def distribute_players(players)
    return if players.empty?

    teams = round.teams.order(:created_at).limit(team_count).to_a
    return if teams.empty?

    ensure_distribution_respects_limits(players, teams)

    max_players_per_team = round&.championship&.max_players_per_team.to_i

    if max_players_per_team.positive?
      required_teams = (players.size.to_f / max_players_per_team).ceil
      teams_to_use = teams.first([required_teams, 1].max)

      players.each_with_index do |player, index|
        team_index = [index / max_players_per_team, teams_to_use.length - 1].min
        PlayerTeam.create!(player:, team: teams_to_use[team_index])
      end
    else
      players.each_with_index do |player, index|
        team = teams[index % teams.length]
        PlayerTeam.create!(player:, team:)
      end
    end
  end

  def adjust_team_count_for_max_limit(player_count)
    championship = round&.championship
    return unless championship.present?

    max = championship.max_players_per_team
    return unless max.to_i.positive?

    required_teams = (player_count.to_f / max).ceil
    return unless required_teams.positive?

    @team_count = [team_count, required_teams].max
  end

  def ensure_distribution_respects_limits(players, teams)
    championship = round&.championship
    return unless championship.present?

    team_total = teams.size
    return if team_total.zero?

    player_total = players.size
    max = championship.max_players_per_team

    if max.to_i.positive? && player_total > max * team_total
      raise PlayerLimitError, "Too many players (#{player_total}) for the maximum of #{max} per team"
    end
  end

  def unique_team_name(sequence, existing_names)
    candidate = "Time #{sequence}"
    while existing_names.include?(candidate)
      sequence += 1
      candidate = "Time #{sequence}"
    end
    candidate
  end
end
