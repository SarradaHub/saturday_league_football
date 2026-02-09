# frozen_string_literal: true

module PlayerStats
  class AddGoalkeeper < ApplicationService
    class MissingParamsError < StandardError; end

    def initialize(match_id:, team_id:, player_id:)
      @match_id = match_id
      @team_id = team_id
      @player_id = player_id
    end

    def call
      validate_params!

      ActiveRecord::Base.transaction do
        stat = PlayerStat.find_or_initialize_by(
          match_id: match_id,
          team_id: team_id,
          player_id: player_id
        )

        stat.goals ||= 0
        stat.assists ||= 0
        stat.own_goals ||= 0
        stat.was_goalkeeper = true

        stat.save!

        ensure_player_in_team!

        stat
      end
    end

    private

    attr_reader :match_id, :team_id, :player_id

    def ensure_player_in_team!
      team = Team.find_by(id: team_id)
      match = Match.find_by(id: match_id)

      return if team.blank? || match.blank?
      match_team_ids = [match.team_1_id, match.team_2_id].compact
      return unless match_team_ids.include?(team.id)

      PlayerTeam.find_or_create_by!(team_id: team.id, player_id: player_id)
    end

    def validate_params!
      if match_id.blank? || team_id.blank? || player_id.blank?
        raise MissingParamsError, "match_id, team_id and player_id are required"
      end
    end
  end
end

