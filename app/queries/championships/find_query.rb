# frozen_string_literal: true

module Championships
  class FindQuery < ApplicationQuery
    def initialize(id:)
      @id = id
    end

    def call
      Championships::CollectionQuery.new(relation: Championship.where(id: id)).call.first!
    end

    private

    attr_reader :id
  end
end
