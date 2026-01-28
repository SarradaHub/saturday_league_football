# frozen_string_literal: true

module Championships
  class FindQuery < ApplicationQuery
    def initialize(id:, includes: [], user_id: nil)
      @id = id
      @includes = includes
      @user_id = user_id
    end

    def call
      Championships::CollectionQuery.new(
        relation: Championship.where(id: id),
        includes: includes,
        user_id: user_id
      ).call.first!
    end

    private

    attr_reader :id, :includes, :user_id
  end
end
