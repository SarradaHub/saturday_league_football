# frozen_string_literal: true

module Players
  class AddToRound < ApplicationService
    def initialize(player:, round_id:)
      @player = player
      @round_id = round_id
    end

    def call
      round = Round.find(round_id)
      # Use find_or_create_by to ensure player_round is created
      player.player_rounds.find_or_create_by(round: round) do |player_round|
        # PlayerRound will be created if it doesn't exist
      end
      # Return reloaded player to ensure associations are fresh
      player.reload
      player
    end

    private

    attr_reader :player, :round_id
  end
end
