# frozen_string_literal: true

module Rounds
  class AddPlayerToLastActiveTeam
    def self.call(round:, player:)
      new(round:, player:).call
    end

    def initialize(round:, player:)
      @round = round
      @player = player
    end

    def call
      return if round.blank? || player.blank?

      championship = round.championship
      return unless championship.present?

      team = find_team_with_capacity || create_new_team
      return if team.blank?

      PlayerTeam.find_or_create_by!(player:, team:)
      team
    end

    private

    attr_reader :round, :player

    def find_team_with_capacity
      active_teams = round.teams.not_blocked.order(created_at: :desc)

      active_teams.find do |team|
        !TeamFormationRules.full_team?(round, team, round.championship)
      end
    end

    def create_new_team
      existing_names = round.teams.pluck(:name)
      team_name = TeamFormationRules.unique_team_name(existing_names.length + 1, existing_names)
      round.teams.create!(name: team_name)
    end
  end
end
