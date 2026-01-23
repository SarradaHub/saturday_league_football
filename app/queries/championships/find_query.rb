# frozen_string_literal: true

module Championships
  class FindQuery < ApplicationQuery
    def initialize(id:, includes: [])
      @id = id
      @includes = includes
    end

    def call
      Championships::CollectionQuery.new(relation: Championship.where(id: id), includes: includes).call.first!
    end

    private

    attr_reader :id, :includes
  end
end
