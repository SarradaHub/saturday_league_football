# frozen_string_literal: true

module Players
  class AddToRound < ApplicationService
    def initialize(player:, round_id:)
      @player = player
      @round_id = round_id
    end

    def call
      round = Round.find(round_id)
      player.rounds << round unless player.rounds.exists?(round.id)
      player
    end

    private

    attr_reader :player, :round_id
  end
end
