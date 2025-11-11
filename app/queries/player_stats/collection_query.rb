# frozen_string_literal: true

module PlayerStats
  class CollectionQuery < ApplicationQuery
    def initialize(relation: PlayerStat.all)
      @relation = relation
    end

    def call
      relation.includes(:player, :team, :match)
    end

    private

    attr_reader :relation
  end
end
