# frozen_string_literal: true

module Matches
  class PlayerStatsQuery < ApplicationQuery
    def initialize(match:, team:)
      @match = match
      @team = team
    end

    def call
      return PlayerStat.none if team.blank?

      PlayerStat.includes(:player, :team)
                .where(match: match, team: team)
    end

    private

    attr_reader :match, :team
  end
end
