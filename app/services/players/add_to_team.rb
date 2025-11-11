# frozen_string_literal: true

module Players
  class AddToTeam < ApplicationService
    def initialize(player:, team_id:)
      @player = player
      @team_id = team_id
    end

    def call
      team = Team.find(team_id)
      player.teams << team unless player.teams.exists?(team.id)
      player
    end

    private

    attr_reader :player, :team_id
  end
end
