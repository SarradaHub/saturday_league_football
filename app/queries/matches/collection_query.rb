# frozen_string_literal: true

module Matches
  class CollectionQuery < ApplicationQuery
    def initialize(relation: Match.all)
      @relation = relation
    end

    def call
      relation
        .includes(:round, :team_1, :team_2, :winning_team, team_1: :players, team_2: :players)
        .order(created_at: :desc)
    end

    private

    attr_reader :relation
  end
end
