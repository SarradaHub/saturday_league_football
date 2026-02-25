# frozen_string_literal: true

module Championships
  class UpdatePlayersCount < ApplicationService
    def initialize(championship:)
      @championship = championship
    end

    def call
      return unless championship.present?
      return if championship.destroyed? || championship.marked_for_destruction?

      begin
        count = championship.players.distinct.count
        championship.update_column(:players_count, count || 0)
      rescue ActiveRecord::RecordNotFound, NoMethodError
      end
    end

    private

    attr_reader :championship
  end
end
