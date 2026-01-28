# frozen_string_literal: true

module Championships
  class UpdatePlayersCount < ApplicationService
    def initialize(championship:)
      @championship = championship
    end

    def call
      return unless championship.present?

      championship.update_column(
        :players_count,
        championship.players.distinct.count
      )
    end

    private

    attr_reader :championship
  end
end
