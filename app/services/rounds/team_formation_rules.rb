# frozen_string_literal: true

module Rounds
  module TeamFormationRules
    RESERVED_SLOTS_FOR_GOALKEEPER = 1

    class << self
      def slots_per_team(championship)
        return 0 if championship.blank?

        max = championship.max_players_per_team.to_i
        [max - RESERVED_SLOTS_FOR_GOALKEEPER, 1].max
      end

      def field_players_count(round, team)
        return (team.players_count || team.players.count) if round.blank?

        team.players.where(
          id: round.player_rounds.where(goalkeeper_only: false).select(:player_id)
        ).count
      end

      def full_team?(round, team, championship)
        slots = slots_per_team(championship)
        return true unless slots.positive?

        field_players_count(round, team) >= slots
      end

      def unique_team_name(sequence, existing_names)
        candidate = "Time #{sequence}"
        while existing_names.include?(candidate)
          sequence += 1
          candidate = "Time #{sequence}"
        end
        candidate
      end
    end
  end
end
