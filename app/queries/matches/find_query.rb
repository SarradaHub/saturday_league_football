# frozen_string_literal: true

module Matches
  class FindQuery < ApplicationQuery
    def initialize(id:)
      @id = id
    end

    def call
      Matches::CollectionQuery.new(relation: Match.where(id: id)).call.first!
    end

    private

    attr_reader :id
  end
end
