# frozen_string_literal: true

module Matches
  class Finalize < ApplicationService
    def initialize(match:)
      @match = match
    end

    def call
      team_1_goals = calculate_goals_for(match.team_1, match.team_2)
      team_2_goals = calculate_goals_for(match.team_2, match.team_1)

      is_draw = team_1_goals == team_2_goals
      winning_team_id = if is_draw
                          nil
      elsif team_1_goals > team_2_goals
                          match.team_1_id
      else
                          match.team_2_id
      end

      match.update!(
        winning_team_id: winning_team_id,
        draw: is_draw
      )

      match
    end

    private

    attr_reader :match

    def calculate_goals_for(team, opponent)
      return 0 if team.blank?

      team_stats = Matches::PlayerStatsQuery.call(match: match, team: team)
      team_goals = team_stats.sum(&:goals)
      opponent_own_goals = if opponent.blank?
                             0
      else
                             Matches::PlayerStatsQuery.call(match: match, team: opponent).sum(&:own_goals)
      end

      team_goals + opponent_own_goals
    end
  end
end
