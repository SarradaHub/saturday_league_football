# frozen_string_literal: true

module Players
  class CollectionQuery < ApplicationQuery
    def initialize(championship_id: nil)
      @championship_id = championship_id
    end

    def call
      scope = Player.includes(:player_stats, :rounds, :teams)
      scope = scope.in_championship(championship_id) if championship_id.present?
      scope.order(:name)
    end

    private

    attr_reader :championship_id
  end
end
