# frozen_string_literal: true

module Rounds
  class FindQuery < ApplicationQuery
    def initialize(id:)
      @id = id
    end

    def call
      Rounds::CollectionQuery.new(relation: Round.where(id: id)).call.first!
    end

    private

    attr_reader :id
  end
end
