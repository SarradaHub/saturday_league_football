# frozen_string_literal: true

module Players
  class AddToRound < ApplicationService
    def initialize(player:, round_id:, goalkeeper_only: false)
      @player = player
      @round_id = round_id
      @goalkeeper_only = goalkeeper_only
    end

    def call
      round = Round.find(round_id)
      pr = player.player_rounds.find_or_initialize_by(round: round)
      pr.goalkeeper_only = goalkeeper_only || false
      pr.save!
      player.reload
      player
    end

    private

    attr_reader :player, :round_id, :goalkeeper_only
  end
end
