# frozen_string_literal: true

module Players
  class AddToTeam < ApplicationService
    def initialize(player:, team_id:)
      @player = player
      @team_id = team_id
    end

    def call
      team = Team.find(team_id)
      player_team = PlayerTeam.with_deleted.find_by(player_id: player.id, team_id: team.id)
      if player_team
        player_team.restore if player_team.deleted?
      else
        player.teams << team unless player.teams.exists?(team.id)
      end
      player
    end

    private

    attr_reader :player, :team_id
  end
end
