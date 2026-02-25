# frozen_string_literal: true

module LeagueEngine
  # Fachada principal da engine de regras de jogo (partidas, substituições, goleiro).
  class Engine
    class << self
      def suggest_next_match(round:)
        MatchSequence.new(round: round).suggest
      end

      def create_next_match(round:, winner_team_id: nil)
        MatchSequence.new(round: round, winner_team_id: winner_team_id).create_next_match
      end

      def redistribute_after_finalize(match:)
        MatchSequence.redistribute_after_finalize(match)
      end

      def finalize_match(match:)
        Matches::Finalize.call(match: match)
      end

      def substitute_in_match(match:, player_id:, replacement_player_id:, team_id:)
        Matches::SubstitutePlayer.call(
          match: match,
          player_id: player_id,
          replacement_player_id: replacement_player_id,
          team_id: team_id
        )
      end

      def replace_in_round(round:, player_id:, match_id: nil)
        Substitutions::ReplacePlayer.call(round: round, player_id: player_id, match_id: match_id)
      end

      def add_goalkeeper(match_id:, team_id:, player_id:)
        PlayerStats::AddGoalkeeper.call(
          match_id: match_id,
          team_id: team_id,
          player_id: player_id
        )
      end

      def bulk_update_player_stats(match_id:, payload:)
        PlayerStats::BulkUpsert.call(match_id: match_id, payload: payload)
      end
    end
  end
end
