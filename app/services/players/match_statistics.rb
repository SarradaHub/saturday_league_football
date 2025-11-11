# frozen_string_literal: true

module Players
  class MatchStatistics < ApplicationService
    def initialize(player:, match:, team:, round:)
      @player = player
      @match = match
      @team = team
      @round = round
    end

    def call
      {
        goals_in_match: aggregate_for(:goals),
        assists_in_match: aggregate_for(:assists),
        own_goals_in_match: aggregate_for(:own_goals),
        total_matches_for_team: matches_for_team
      }
    end

    private

    attr_reader :player, :match, :team, :round

    def aggregate_for(attribute)
      player.player_stats.where(match: match).sum(attribute)
    end

    def matches_for_team
      return 0 unless player.teams.exists?(team.id)

      Teams::MatchesQuery.call(team: team).where(round: round).count
    end
  end
end
