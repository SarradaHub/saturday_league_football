# frozen_string_literal: true

module Rounds
  class FindQuery < ApplicationQuery
    def initialize(id:, user_id: nil)
      @id = id
      @user_id = user_id
    end

    def call
      Rounds::CollectionQuery.new(relation: Round.where(id: id), user_id: user_id).call.first!
    end

    private

    attr_reader :id, :user_id
  end
end
