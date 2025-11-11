# frozen_string_literal: true

module Teams
  class FindQuery < ApplicationQuery
    def initialize(id:)
      @id = id
    end

    def call
      Teams::CollectionQuery.new(relation: Team.where(id: id)).call.first!
    end

    private

    attr_reader :id
  end
end
