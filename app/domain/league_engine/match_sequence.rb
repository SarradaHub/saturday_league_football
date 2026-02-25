# frozen_string_literal: true

module LeagueEngine
  # Adaptador entre a engine e Rounds::NextMatchGenerator.
  class MatchSequence
    class << self
      def redistribute_after_finalize(match)
        Rounds::NextMatchGenerator.redistribute_after_finalize(match)
      end
    end

    def initialize(round:, winner_team_id: nil)
      @round = round
      @winner_team_id = winner_team_id
    end

    def suggest
      call_next_match(create_match: false)
    end

    def create_next_match
      call_next_match(create_match: true)
    end

    private

    attr_reader :round, :winner_team_id

    def call_next_match(create_match:)
      Rounds::NextMatchGenerator.call(
        round: round,
        winner_team_id: winner_team_id,
        create_match: create_match
      )
    end
  end
end
