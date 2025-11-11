# frozen_string_literal: true

module Rounds
  class CollectionQuery < ApplicationQuery
    def initialize(relation: Round.all)
      @relation = relation
    end

    def call
      relation
        .includes(:matches, :players, :teams)
        .order(round_date: :desc)
    end

    private

    attr_reader :relation
  end
end
