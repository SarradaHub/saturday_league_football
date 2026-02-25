# frozen_string_literal: true

module Rounds
  class RoundTeamGenerator
    DEFAULT_TEAM_COUNT = 2

    class PlayerLimitError < StandardError; end

    def self.call(round, team_count: nil, active_teams_only: false)
      new(round, team_count:, active_teams_only:).call
    end

    def initialize(round, team_count: nil, active_teams_only: false)
      @round = round
      @active_teams_only = active_teams_only
      base_count = active_teams_only ? round.teams.not_blocked.count : round.teams.count
      @team_count = team_count || [base_count, DEFAULT_TEAM_COUNT].max
    end

    def call
      return if round.blank?

      if active_teams_only
        call_active_teams_only
      else
        call_full_rebalance
      end
    end

    private

    attr_reader :round, :team_count, :active_teams_only

    def call_active_teams_only
      active_team_ids = round.teams.not_blocked.pluck(:id)
      return if active_team_ids.empty?

      # Redistribute only active players currently in active teams - preserve blocked teams.
      # Order follows last distribution: teams by created_at, players within team by player_teams.created_at.
      players = active_players_in_distribution_order(active_team_ids)
      adjust_team_count_for_max_limit(players.size)

      teams_to_use = round.teams.not_blocked.order(:created_at).limit(team_count).to_a
      adjust_team_count_for_active(teams_to_use.size, players.size)

      ActiveRecord::Base.transaction do
        ensure_minimum_active_teams(teams_to_use, players.any?)
        clear_memberships_for_teams(active_team_ids)
        distribute_players_to_teams(players, teams_to_use)
      end
    end

    def call_full_rebalance
      players = ordered_players
      adjust_team_count_for_max_limit(players.size)

      ActiveRecord::Base.transaction do
        ensure_minimum_teams(players.any?)
        clear_memberships
        distribute_players(players)
      end
    end

    def adjust_team_count_for_active(active_count, player_count)
      championship = round&.championship
      return unless championship.present?

      slots = TeamFormationRules.slots_per_team(championship)
      return unless slots.positive? && player_count.positive?

      required = (player_count.to_f / slots).ceil
      @team_count = [team_count, required, active_count].max
    end

    def ensure_minimum_active_teams(teams, players_present)
      return unless players_present

      missing = team_count - teams.size
      return if missing <= 0

      existing_names = round.teams.pluck(:name)
      missing.times do
        index = existing_names.length + 1
        name = TeamFormationRules.unique_team_name(index, existing_names)
        round.teams.create!(name:)
        existing_names << name
      end
    end

    def clear_memberships_for_teams(team_ids)
      return if team_ids.blank?

      PlayerTeam.with_deleted.where(team_id: team_ids).delete_all
      Team.where(id: team_ids).update_all(players_count: 0)
    end

    def distribute_players_to_teams(players, teams)
      return if players.empty? || teams.empty?

      teams = round.teams.not_blocked.order(:created_at).limit(team_count).to_a
      return if teams.empty?

      ensure_distribution_respects_limits(players, teams)

      championship = round&.championship
      slots = TeamFormationRules.slots_per_team(championship)

      if slots.positive?
        required_teams = (players.size.to_f / slots).ceil
        teams_to_use = teams.first([required_teams, 1].max)

        players.each_with_index do |player, index|
          team_index = [index / slots, teams_to_use.length - 1].min
          PlayerTeam.create!(player:, team: teams_to_use[team_index])
        end
      else
        players.each_with_index do |player, index|
          team = teams[index % teams.length]
          PlayerTeam.create!(player:, team:)
        end
      end
    end

    def ordered_players
      round.player_rounds
          .where(blocked: false, goalkeeper_only: false)
          .includes(:player)
          .order(:created_at)
          .map(&:player)
    end

    # Order from last distribution: active teams by created_at, players within each team by player_teams.created_at.
    # Excludes blocked and goalkeeper_only players.
    def active_players_in_distribution_order(active_team_ids)
      excluded_ids = round.player_rounds
        .where('blocked = true OR goalkeeper_only = true')
        .pluck(:player_id)
        .to_set

      round.teams
        .where(id: active_team_ids)
        .order(:created_at)
        .flat_map do |team|
          team.player_teams
            .includes(:player)
            .order(:created_at)
            .map(&:player)
            .compact
            .reject { |p| excluded_ids.include?(p.id) }
        end
    end

    def ensure_minimum_teams(players_present)
      return unless players_present

      missing = team_count - round.teams.count
      return if missing <= 0

      existing_names = round.teams.pluck(:name)
      missing.times do
        index = existing_names.length + 1
        name = TeamFormationRules.unique_team_name(index, existing_names)
        round.teams.create!(name:)
        existing_names << name
      end
    end

    def clear_memberships
      team_ids = round.teams.select(:id)
      PlayerTeam.with_deleted.where(team_id: team_ids).delete_all
      Team.where(id: team_ids).update_all(players_count: 0)
    end

    def distribute_players(players)
      return if players.empty?

      teams = round.teams.order(:created_at).limit(team_count).to_a
      return if teams.empty?

      ensure_distribution_respects_limits(players, teams)

      championship = round&.championship
      slots = TeamFormationRules.slots_per_team(championship)

      if slots.positive?
        required_teams = (players.size.to_f / slots).ceil
        teams_to_use = teams.first([required_teams, 1].max)

        players.each_with_index do |player, index|
          team_index = [index / slots, teams_to_use.length - 1].min
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

      slots = TeamFormationRules.slots_per_team(championship)
      return unless slots.positive?

      required_teams = (player_count.to_f / slots).ceil
      return unless required_teams.positive?

      @team_count = [team_count, required_teams].max
    end

    def ensure_distribution_respects_limits(players, teams)
      championship = round&.championship
      return unless championship.present?

      team_total = teams.size
      return if team_total.zero?

      player_total = players.size
      slots = TeamFormationRules.slots_per_team(championship)

      if slots.positive? && player_total > slots * team_total
        raise PlayerLimitError, "Too many players (#{player_total}) for the maximum of #{slots} per team"
      end
    end
  end
end
