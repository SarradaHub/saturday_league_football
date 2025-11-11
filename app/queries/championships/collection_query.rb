# frozen_string_literal: true

module Championships
  class CollectionQuery < ApplicationQuery
    def initialize(relation: Championship.all)
      @relation = relation
    end

    def call
      relation
        .includes(rounds: :matches, players: %i[player_stats teams])
        .order(updated_at: :desc)
    end

    private

    attr_reader :relation
  end
end
