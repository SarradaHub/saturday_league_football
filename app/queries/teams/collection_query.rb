# frozen_string_literal: true

module Teams
  class CollectionQuery < ApplicationQuery
    def initialize(relation: Team.all)
      @relation = relation
    end

    def call
      relation.includes(:players, :round).order(:name)
    end

    private

    attr_reader :relation
  end
end
