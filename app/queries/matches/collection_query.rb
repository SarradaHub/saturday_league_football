# frozen_string_literal: true

module Matches
  class CollectionQuery < ApplicationQuery
    def initialize(relation: Match.all, includes: [], page: nil, per_page: nil, user_id: nil)
      @relation = relation
      @includes = includes
      @page = page
      @per_page = per_page
      @user_id = user_id
    end

    def call
      scope = relation.order(created_at: :desc)
      
      # Filter by user_id via championship if provided
      scope = scope.joins(round: :championship).where(championships: { user_id: user_id }) if user_id.present?

      # Apply includes - add default includes for MatchPresenter when used in lists
      if includes.any?
        scope = apply_includes(scope, includes)
      else
        # Use direct includes for default associations
        scope = scope.includes({ team_1: :players }, { team_2: :players }, :winning_team, :round)
      end

      # Apply pagination if specified
      if page && per_page
        offset = (page - 1) * per_page
        scope = scope.limit(per_page).offset(offset)
      end

      scope
    end

    private

    attr_reader :relation, :includes, :page, :per_page, :user_id

    def apply_includes(scope, includes_list)
      includes_hash = {}
      includes_list.each do |include_str|
        parts = include_str.split('.').map(&:to_sym)
        current = includes_hash

        parts.each_with_index do |part, index|
          if index == parts.length - 1
            current[part] = {}
          else
            current[part] ||= {}
            current = current[part]
          end
        end
      end

      if includes_hash.any?
        scope.includes(includes_hash)
      else
        scope.includes(includes_list.map(&:to_sym))
      end
    end
  end
end
