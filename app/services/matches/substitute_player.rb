# frozen_string_literal: true

module Matches
  class SubstitutePlayer < ApplicationService
    class PlayerNotInTeamError < StandardError; end
    class ReplacementNotInRoundError < StandardError; end
    class ReplacementInMatchError < StandardError; end
    class InvalidTeamError < StandardError; end

    def initialize(match:, player_id:, replacement_player_id:, team_id:)
      @match = match
      @player_id = player_id.to_i
      @replacement_player_id = replacement_player_id.to_i
      @team_id = team_id.to_i
    end

    def call
      validate_team!
      validate_player_in_team!
      validate_replacement_in_round!
      validate_replacement_not_in_match!

      removed_player = Player.find(player_id)
      replacement_player = Player.find(replacement_player_id)
      team = Team.find(team_id)

      ActiveRecord::Base.transaction do
        player_team = PlayerTeam.find_by(player_id: player_id, team_id: team_id)
        player_team&.soft_delete

        unless replacement_player.teams.exists?(team_id)
          Players::AddToTeam.call(player: replacement_player, team_id: team_id)
        end
      end

      {
        removed_player_id: player_id,
        removed_player_name: removed_player.display_name,
        replacement_player_id: replacement_player_id,
        replacement_player_name: replacement_player.display_name,
        team_id: team_id,
        team_name: team.name
      }
    end

    private

    attr_reader :match, :player_id, :replacement_player_id, :team_id

    def validate_team!
      unless [match.team_1_id, match.team_2_id].include?(team_id)
        raise InvalidTeamError, "Team #{team_id} is not part of match #{match.id}"
      end
    end

    def validate_player_in_team!
      team = Team.find(team_id)
      unless team.players.exists?(id: player_id)
        raise PlayerNotInTeamError, "Player #{player_id} is not in team #{team_id}"
      end
    end

    def validate_replacement_in_round!
      unless match.round.players.exists?(id: replacement_player_id)
        raise ReplacementNotInRoundError, "Replacement player #{replacement_player_id} is not in round #{match.round_id}"
      end
    end

    def validate_replacement_not_in_match!
      match_team_ids = [match.team_1_id, match.team_2_id].compact
      other_team_ids = match_team_ids - [team_id]
      return if other_team_ids.empty?

      replacement_teams = Player.find(replacement_player_id).teams.where(id: other_team_ids)
      raise ReplacementInMatchError, "Replacement player #{replacement_player_id} is already in one of the match teams" if replacement_teams.exists?
    end
  end
end
