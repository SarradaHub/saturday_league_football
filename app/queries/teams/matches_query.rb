# frozen_string_literal: true

module Teams
  class MatchesQuery < ApplicationQuery
    def initialize(team:)
      @team = team
    end

    def call
      Match.where('team_1_id = :team_id OR team_2_id = :team_id', team_id: team.id)
           .includes(:round, :team_1, :team_2, :winning_team)
    end

    private

    attr_reader :team
  end
end
