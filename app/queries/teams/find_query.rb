# frozen_string_literal: true

module Teams
  class FindQuery < ApplicationQuery
    def initialize(id:, user_id: nil)
      @id = id
      @user_id = user_id
    end

    def call
      Teams::CollectionQuery.new(relation: Team.where(id: id), user_id: user_id).call.first!
    end

    private

    attr_reader :id, :user_id
  end
end
